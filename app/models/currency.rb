class Currency < ApplicationRecord
  has_many :accounts
  has_many :symbol_aliases
  has_many :rates, dependent: :delete_all
  has_many :tokens, class_name: Currency.to_s, foreign_key: :platform_id
  has_many :stablecoins, class_name: Currency.to_s, foreign_key: :stablecoin_id
  belongs_to :platform, class_name: Currency.to_s, foreign_key: :platform_id, optional: true
  belongs_to :stablecoin, class_name: Currency.to_s, foreign_key: :stablecoin_id, optional: true
  has_attached_file :icon

  scope :fiat, -> { where(fiat: true) }
  scope :crypto, -> { where(fiat: false) }
  scope :active, -> { where(active: true) }
  scope :prioritized, -> { order(priority: :desc, rank: :asc) }
  default_scope { prioritized }

  before_validation :set_defaults
  validate :ensure_stablecoin_is_valid
  validates_presence_of :name, :symbol, :added_at
  validates_attachment_content_type :icon, content_type: /\Aimage/
  validates_attachment_file_name :icon, matches: [/png|jpg|svg\z/i]

  serialize :external_data, HashSerializer
  store :market_data, accessors: [:recent_rates, :volume, :market_cap, :circulating_supply, :change1h, :change1d, :change7d], coder: JSON

  def txns
    Transaction.by_currency_id(id)
  end

  def self.usd
    cache_on_prod('USD')
  end

  def self.eur
    cache_on_prod('EUR')
  end

  # currencies may contain duplicates
  def self.eager_load_rates(currencies, date=Time.now)
    stablecoin_parents = currencies.map(&:stablecoin).compact
    currencies = currencies.reject{ |x| x.id == usd.id || x.stablecoin? } + stablecoin_parents

    # get rates from live market rates
    if date > 1.minute.ago
      currencies.each{ |x| x.price && x.set_usd_rate(x.price) }
    end

    remaining = currencies.reject(&:usd_rate_loaded?)
    if remaining.any?
      rates = Rate
        .where(currency_id: remaining.map(&:id).uniq)
        .where('date < ?', date)
        .order(currency_id: :asc, date: :desc)
        .select('DISTINCT ON (currency_id) rates.currency_id, rates.quoted_rate as rate')
        .as_json

      rates.each do |rate|
        selected = currencies.select{ |x| x.id == rate['currency_id'] }
        selected.each{ |x| x.set_usd_rate(rate['rate']) }
      end

      currencies.reject(&:usd_rate_loaded?).each{ |x| x.set_usd_rate(0.0) }
    end
  end

  def set_usd_rate(rate)
    @rate = rate.to_d
  end

  def usd_rate_loaded?
    !@rate.nil?
  end

  def usd_rate
    @rate ||=
      if id == Currency.usd.id || (stablecoin? && stablecoin_id == Currency.usd.id)
        1
      elsif stablecoin?
        stablecoin.usd_rate
      else
        price || rates.order(date: :desc).first.try(:quoted_rate) || 0
      end
  end

  def crypto?
    !fiat?
  end

  def stablecoin?
    stablecoin_id.present?
  end

  # returns array of prices with data ordered oldest to newest
  def sparkline
    return [] unless recent_rates
    recent_rates.map { |r| r['rate'].to_d }.reverse
  end

  def add_recent_rate(date, rate)
    self.recent_rates ||= []
    self.recent_rates.unshift('date' => date, 'rate' => rate)
    self.recent_rates.pop if recent_rates.count > 24
  end

  private

  def set_defaults
    self.added_at = Time.now if added_at.nil?
    self.token_address = token_address.strip.downcase if token_address.present?
    self.rank = nil if rank == 0
    self.symbol.upcase! if symbol
    self.priority = priority > 0 ? priority : 0
    self.priority = -1 if added_by_user?
  end

  def ensure_stablecoin_is_valid
    if stablecoin?
      errors.add(:base, "stablecoins can only be pegged to fiat currencies") unless Currency.fiat.where(id: stablecoin_id).exists?
    end
  end

  def self.cache_on_prod(symbol)
    if Rails.env.test?
      fiat.find_by(symbol: symbol)
    else
      @cached ||= {}
      @cached[symbol] ||= fiat.find_by(symbol: symbol)
    end
  end
end
