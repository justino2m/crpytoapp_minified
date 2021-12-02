class User < ApplicationRecord
  VALID_TAX_PERIODS = ['initial', 'later'].freeze # used for ireland

  has_secure_password
  has_many :entries, dependent: :delete_all
  has_many :investments, dependent: :delete_all
  has_many :txns, class_name: Transaction.to_s, dependent: :delete_all
  has_many :accounts, dependent: :delete_all
  has_many :wallets, dependent: :delete_all
  has_many :assets, dependent: :delete_all
  has_many :snapshots, dependent: :delete_all
  has_many :reports, dependent: :delete_all
  has_many :csv_imports, dependent: :delete_all
  has_many :job_statuses, dependent: :delete_all
  has_many :subscriptions
  has_many :payouts
  has_one :active_subscription,
          -> { where('expires_at > ?', Time.now).where(refunded_at: nil).order(created_at: :desc) },
          class_name: Subscription.to_s
  has_one :my_coupon, -> { active.order(created_at: :desc) }, foreign_key: :owner_id, class_name: Coupon.to_s
  belongs_to :referring_coupon, class_name: Coupon.to_s, foreign_key: :via, primary_key: :code, optional: true
  belongs_to :discount_coupon, class_name: Coupon.to_s, optional: true

  belongs_to :country
  belongs_to :base_currency, class_name: Currency.to_s
  belongs_to :display_currency, class_name: Currency.to_s
  has_attached_file :avatar, styles: { medium: "300x300>", thumb: "100x100>" }

  scope :active, -> { where('last_seen_at > ?', 10.days.ago) }

  before_validation :set_defaults
  validates_presence_of :name, :email, :base_currency, :display_currency
  validates :email, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates_attachment_content_type :avatar, content_type: /\Aimage\/.*\z/
  validates_attachment_file_name :avatar, matches: [/png\z/, /jpe?g\z/]
  validates_inclusion_of :cost_basis_method, in: Investment::COST_BASIS_METHODS
  validates_inclusion_of :year_start_day, in: 1..31
  validates_inclusion_of :year_start_month, in: 1..12
  validate :ensure_timezone_is_valid
  validate :ensure_base_currency_is_fiat
  validate :ensure_tax_period_is_valid

  before_save { self.last_seen_at = Time.now }
  before_create { self.uuid = SecureRandom.uuid }
  before_save { self.api_token = create_token if password_digest_changed? }
  after_update :recreate_investments
  after_create_commit :send_welcome_email

  # search: x.preferences_where(account_based_cost_basis: true)
  jsonb_accessor(
    :preferences,
    year_start_day: :integer,
    year_start_month: :integer,
    timezone: :string,
    tax_period: :string, # only used for ireland
    settings_reviewed: [:boolean, default: false],
    wallets_reviewed: [:boolean, default: false],
    onboarding_reviewed: [:boolean, default: false],
    account_based_cost_basis: [:boolean, default: false],
    realize_gains_on_exchange: [:boolean, default: false],
    realize_transfer_fees: [:boolean, default: false],
    copy_tax_settings: [:boolean, default: true],
    treat_margin_gains_as_capital_gains: [:boolean, default: true]
  )

  def login!
    update_attributes!(api_token: create_token, password_reset_token: nil)
  end

  def logout!
    update_attributes!(api_token: nil, password_reset_token: nil)
  end

  def self.create_affiliate_account!(email)
    User.create!(
      name: email.split('@').first,
      email: email,
      password: SecureRandom.urlsafe_base64(nil, false).first(12),
      affiliate_only: true
    )
  end

  def change_password!(new_pass)
    update_attributes!(api_token: nil, password_reset_token: nil, password: new_pass)
  end

  def update_activity!(ip)
    update_columns(last_seen_at: Time.now, ip_address: ip) if last_seen_at < 15.minutes.ago
  end

  def send_welcome_email
    if affiliate_only?
      # UserMailer.with(user: self, password: password).affiliate_welcome_email.deliver_later
    else
      # UserMailer.with(user: self).welcome_email.deliver_later
    end
  end

  def send_password_reset_instructions
    update_attributes!(password_reset_token: create_token)
    # UserMailer.with(user: self).password_reset.deliver_later
  end

  def year_start_end_dates(year)
    Time.use_zone(timezone || country.timezone || 'UTC') do
      if irish?
        if tax_period.blank? || tax_period == 'initial'
          [Time.zone.parse("#{year}-1-1"), Time.zone.parse("#{year}-11-30").end_of_day]
        elsif tax_period == 'later'
          [Time.zone.parse("#{year}-12-1"), Time.zone.parse("#{year}-12-31").end_of_day]
        else
          raise "invalid tax_period for ireland: #{tax_period}"
        end
      else
        from = Time.zone.parse("#{year}-#{year_start_month}-#{year_start_day}")
        to = from + 1.year - 1.second
        [from, to]
      end
    end
  end

  def copy_settings_from_country
    self.timezone = country.timezone
    self.year_start_day = country.tax_year_start_day
    self.year_start_month = country.tax_year_start_month
    self.cost_basis_method = country.tax_cost_basis_method
    self.realize_gains_on_exchange = true
  end

  def total_fiat_worth
    filtered_assets = assets.includes(currency: :stablecoin).select(&:fiat?)
    worth_of_assets(filtered_assets)
  end

  def total_crypto_worth
    filtered_assets = assets.includes(currency: :stablecoin).reject(&:fiat?)
    worth_of_assets(filtered_assets)
  end

  def total_worth
    filtered_assets = assets.includes(currency: :stablecoin)
    worth_of_assets(filtered_assets)
  end

  def activate_affiliate!
    return if my_coupon.is_a? AffiliateCoupon
    my_coupon&.deactivate!
    self.my_coupon = AffiliateCoupon.create!(owner: self)
  end

  def my_coupon
    super || (self.my_coupon = (affiliate_only? ? AffiliateCoupon : ReferFriendCoupon).create!(owner: self))
  end

  def apply_coupon(code)
    coupon = Coupon.active.find_by(code: code.upcase)
    if coupon.nil?
      errors.add(:coupon, 'does not exist or has expired')
    elsif coupon.is_a?(AffiliateCoupon) || coupon.is_a?(ReferFriendCoupon)
      errors.add(:coupon, 'can not be used')
    elsif !coupon.eligible?(self)
      errors.add(:coupon, 'can not be applied')
    else
      update_attributes!(discount_coupon: coupon)
      return coupon
    end
    nil
  end

  def credit_balance
    [0.0, my_coupon.commission_subs.sum(:commission_total) - payouts.sum(:amount)].max
  end

  def reserved_credits
    return 0.0 unless my_coupon.is_a?(AffiliateCoupon)
    my_coupon.commission_subs.where('created_at > ?', 30.days.ago).sum(:commission_total)
  end

  def create_free_subscription
    subscriptions.create!(
      plan: Plan.last,
      amount_paid: 0,
      expires_at: 1.year.from_now,
      max_txns: 5000
    )
  end

  def subscriber?
    subscriptions.any?
  end

  def gains_blocked?
    !subscriber? && txns.count > 10000
  end

  def gains_progress(display=true)
    total = txns.count
    progress = 100 - (total > 0 ? (txns.pending_gains.count / total.to_d * 100.0).round(2) : 0)
    if display
      progress.to_s + '%'
    else
      progress
    end
  end

  def rebuild_gains!
    update_attributes!(rebuild_scheduled: true)
    UpdateUserStatsWorker.perform_later(id)
  end

  private

  def create_token
    SecureRandom.urlsafe_base64(nil, false)
  end

  def set_defaults
    self.country ||= country_from_ip || Country.usa
    self.base_currency ||= country.currency
    self.display_currency ||= country.currency
    self.timezone ||= country.timezone
    self.year_start_day ||= 1
    self.year_start_month ||= 1
    self.cost_basis_method ||= Investment::FIFO
    self.email.downcase! if email.present?
    self.via.strip.upcase! if via.present?
  end

  def country_from_ip
    return unless ip_address
    result = Geocoder.search(ip_address).first
    return unless result
    iso_country = IsoCountryCodes.find(result.country) { nil }
    return unless iso_country
    Country.find_by(code: iso_country.alpha3)
  end

  def ensure_timezone_is_valid
    return unless timezone
    unless TZInfo::Timezone.all_identifiers.include?(timezone)
      errors.add(:timezone, 'is invalid')
    end
  end

  def ensure_base_currency_is_fiat
    if base_currency && base_currency.crypto?
      self.errors.add(:base_currency_id, 'must be fiat')
    end
  end

  def ensure_tax_period_is_valid
    if irish?
      errors.add(:tax_period, "is invalid") if !tax_period.blank? && !VALID_TAX_PERIODS.include?(tax_period)
    end
  end

  def recreate_investments
    return unless saved_change_to_base_currency_id? ||
      saved_change_to_realize_gains_on_exchange? ||
      saved_change_to_realize_transfer_fees? ||
      saved_change_to_account_based_cost_basis? ||
      saved_change_to_cost_basis_method? ||
      saved_change_to_country_id?

    rebuild_gains!
  end

  def worth_of_assets(filtered_assets)
    currencies = filtered_assets.map(&:currency).to_a
    Currency.eager_load_rates(currencies + [base_currency])
    multiplier = base_currency.usd_rate
    filtered_assets.sum { |x| (x.currency.usd_rate * x.total_amount) / multiplier }
  end

  def irish?
    country.code == 'IRL'
  end
end
