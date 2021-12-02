class Transaction < ApplicationRecord
  include TxnValueCalculator

  TYPES = [
    BUY = 'buy',
    SELL = 'sell',
    EXCHANGE = 'exchange',
    TRANSFER = 'transfer',
    FIAT_DEPOSIT = 'fiat_deposit',
    FIAT_WITHDRAWAL = 'fiat_withdrawal',
    CRYPTO_DEPOSIT = 'crypto_deposit',
    CRYPTO_WITHDRAWAL = 'crypto_withdrawal',
  ].freeze

  # note: labels are saved in the wallets table too so ensure they are updated when these change!
  LABELS = [
    REALIZED_GAIN = 'realized_gain',
    AIRDROP = 'airdrop',
    FORK = 'fork',
    MINING = 'mining',
    REWARD = 'staking',
    LOAN_INTEREST = 'loan_interest',
    OTHER_INCOME = 'other_income',
    GIFT = 'gift',
    LOST = 'lost',
    DONATION = 'donation',
    COST = 'cost',
    MARGIN_TRADE_FEE = 'margin_trade_fee',
    MARGIN_INTEREST_FEE = 'margin_interest_fee',
  ].freeze

  INCOME_LABELS = [AIRDROP, FORK, MINING, REWARD, LOAN_INTEREST, OTHER_INCOME].freeze
  EXPENSE_LABELS = [COST, MARGIN_TRADE_FEE, MARGIN_INTEREST_FEE].freeze
  SPECIAL_LABELS = [GIFT, LOST, DONATION].freeze

  CRYPTO_DEPOSIT_LABELS = [REALIZED_GAIN] + INCOME_LABELS
  CRYPTO_WITHDRAWAL_LABELS = [REALIZED_GAIN] + EXPENSE_LABELS + SPECIAL_LABELS
  FIAT_WITHDRAWAL_LABELS = [REALIZED_GAIN] + EXPENSE_LABELS
  FIAT_DEPOSIT_LABELS = [REALIZED_GAIN] + INCOME_LABELS
  TRADE_LABELS = []

  alias_attribute :type, :transaction_type

  has_many :entries, dependent: :nullify, inverse_of: :txn
  has_many :investments, dependent: :nullify, inverse_of: :txn

  belongs_to :user
  belongs_to :from_wallet, class_name: Wallet.to_s, optional: true
  belongs_to :to_wallet, class_name: Wallet.to_s, optional: true
  belongs_to :from_account, class_name: Account.to_s, optional: true
  belongs_to :to_account, class_name: Account.to_s, optional: true
  belongs_to :fee_account, class_name: Account.to_s, optional: true
  belongs_to :from_currency, class_name: Currency.to_s, optional: true
  belongs_to :to_currency, class_name: Currency.to_s, optional: true
  belongs_to :fee_currency, class_name: Currency.to_s, optional: true
  belongs_to :net_worth_currency, class_name: Currency.to_s, optional: true
  belongs_to :fee_worth_currency, class_name: Currency.to_s, optional: true

  scope :fiat_deposits, -> { where(type: FIAT_DEPOSIT) }
  scope :fiat_withdrawals, -> { where(type: FIAT_WITHDRAWAL) }
  scope :crypto_deposits, -> { where(type: CRYPTO_DEPOSIT) }
  scope :crypto_withdrawals, -> { where(type: CRYPTO_WITHDRAWAL) }
  scope :deposits, -> { where(type: [FIAT_DEPOSIT, CRYPTO_DEPOSIT]) }
  scope :withdrawals, -> { where(type: [FIAT_WITHDRAWAL, CRYPTO_WITHDRAWAL]) }
  scope :transfers, -> { where(type: TRANSFER) }
  scope :trades, -> { where(type: [EXCHANGE, BUY, SELL]) }
  scope :exchanges, -> { where(type: EXCHANGE) }
  scope :buys, -> { where(type: BUY) }
  scope :sells, -> { where(type: SELL) }
  scope :manual, -> { where("(from_currency_id IS NOT NULL AND from_source IS NULL) OR (to_currency_id IS NOT NULL AND to_source IS NULL) OR ignored = TRUE") }
  scope :synced, -> { where("(from_currency_id IS NOT NULL AND from_source = 'api') OR (to_currency_id IS NOT NULL AND to_source = 'api')") }
  scope :not_fiat, -> { where.not(type: [FIAT_DEPOSIT, FIAT_WITHDRAWAL]) }
  scope :not_label, ->(label) { where('label IS NULL OR label != ?', label) }

  scope :with_investments, -> { joins(:investments) }
  scope :without_investments, -> { left_joins(:investments).where(investments: { id: nil }) }
  scope :without_entries, -> { left_joins(:entries).where(entries: { id: nil }) }
  scope :pending_gains, -> { where(gain: nil) }
  scope :pending_deletion, -> { where(from_account_id: nil, to_account_id: nil) }
  scope :not_deleted, -> { where("from_account_id IS NOT NULL OR to_account_id IS NOT NULL") }
  scope :not_ignored, -> { where(ignored: false) } # soft delete
  scope :by_account_id, ->(id) { where("from_account_id = :id OR to_account_id = :id OR fee_account_id = :id", id: id) }
  scope :by_currency_id, ->(id) { where("from_currency_id = :id OR to_currency_id = :id OR fee_currency_id = :id", id: id) }
  scope :by_wallet_id, ->(id) { where("from_wallet_id = :id OR to_wallet_id = :id", id: id) }

  before_validation :set_defaults
  validates_inclusion_of :transaction_type, in: TYPES
  validates_presence_of :date
  validates_presence_of :from_wallet_id, if: :should_validate_from
  validates_presence_of :from_account_id, if: :should_validate_from
  validates_presence_of :to_wallet_id, if: :should_validate_to
  validates_presence_of :to_account_id, if: :should_validate_to
  validates_presence_of :fee_account_id, if: :should_validate_fee
  validates_presence_of :from_currency_id, if: :should_validate_from
  validates_presence_of :to_currency_id, if: :should_validate_to
  validates_presence_of :fee_currency_id, if: :should_validate_fee
  validates_numericality_of :from_amount, if: :should_validate_from
  validates_numericality_of :to_amount, if: :should_validate_to
  validates_numericality_of :fee_amount, if: :should_validate_fee
  validate :ensure_valid_transfer, if: :transfer?
  validate :ensure_label_is_valid

  before_update :nullify_cost_basis # this happens automatically when destroying due to dependent: :nullify

  serialize :cached_rates, HashSerializer
  attr_accessor :pending_investments # temporary variable, used in base calculator

  delegate :unmerge_entries!, :merge_entries!, :merge_transfer_entries!, :merge_txn!, :update_from_entries, to: :merger

  def self.soft_delete!
    update_all(from_account_id: nil, to_account_id: nil, fee_account_id: nil)
  end

  # this scope is used for creating investments, do not change!
  # remember: ordering by desc will result in null records first
  def self.ordered(asc = true)
    order, reverse = asc ? %w[ASC DESC] : %w[DESC ASC]

    # note: SortIndexUpdater can sometimes sort transfers before trades if the receiving wallet
    # is trading with the received funds right away however the default is still to order transfers
    # at the end
    priorities = {
      FIAT_DEPOSIT => 0,
      CRYPTO_DEPOSIT => 1,
      BUY => 2,
      EXCHANGE => 3,
      TRANSFER => 3, # same as exchange to allow sort_index to determine order
      SELL => 4,
      CRYPTO_WITHDRAWAL => 5,
      FIAT_WITHDRAWAL => 6,
    }.map { |x, idx| "WHEN transaction_type = '#{x}' THEN #{idx}" }

    # if sort_index is same then transfer should be handled at the end
    transfer_prios = [EXCHANGE, TRANSFER].map.with_index { |x, idx| "WHEN transaction_type = '#{x}' THEN #{idx}" }

    order(Arel.sql("
      date #{order},
      CASE #{priorities.join(' ')} ELSE #{priorities.count} END #{order},
      sort_index #{order},
      CASE #{transfer_prios.join(' ')} ELSE 0 END #{order},
      to_amount #{reverse},
      id #{order}
                   "))
  end

  def self.reverse_ordered
    ordered(false)
  end

  def merger
    @txn_merger ||= TxnBuilder::Merger.new(self)
  end

  def buy?
    self.transaction_type == BUY
  end

  def sell?
    self.transaction_type == SELL
  end

  def exchange?
    self.transaction_type == EXCHANGE
  end

  def transfer?
    self.transaction_type == TRANSFER
  end

  def fiat_deposit?
    self.transaction_type == FIAT_DEPOSIT
  end

  def fiat_withdrawal?
    self.transaction_type == FIAT_WITHDRAWAL
  end

  def crypto_deposit?
    self.transaction_type == CRYPTO_DEPOSIT
  end

  def crypto_withdrawal?
    self.transaction_type == CRYPTO_WITHDRAWAL
  end

  def deposit?
    crypto_deposit? || fiat_deposit?
  end

  def withdrawal?
    crypto_withdrawal? || fiat_withdrawal?
  end

  def trade?
    buy? || sell? || exchange?
  end

  def fee?
    fee_currency_id.present? && fee_amount > 0
  end

  def synced?
    from_source == 'api' || to_source == 'api'
  end

  def manual?
    (from_currency_id.present? && from_source.nil?) || (to_currency_id.present? && to_source.nil?)
  end

  def imported?
    # either api synced or imported by a tagged mapper (i.e. not via sample mapper)
    synced? || (!manual? && importer_tag.present?)
  end

  def update_totals
    val = calculate_net_value
    self.missing_rates = val.nil?
    self.net_value = val || 0
    self.fee_value = calculate_fee_value || 0
  end

  def update_totals!
    update_totals
    save! if changed?
  end

  def update_account_totals!
    [from_account, to_account, fee_account].compact.uniq.map(&:update_totals!)
  end

  def potential_match
    TransferMatcher.find_potential_match_for_txn(user, self)
  end

  def ignore!
    ActiveRecord::Base.transaction do
      self.ignored = true
      self.negative_balances = false
      entries.ignore!
      save!
    end
  end

  def unignore!
    ActiveRecord::Base.transaction do
      self.ignored = false
      entries.unignore!
      save!
    end
  end

  private

  def set_defaults
    self.net_worth_amount = self.net_worth_currency = nil if net_worth_amount.blank?
    self.fee_worth_amount = self.fee_worth_currency = nil if fee_worth_amount.blank?
    self.label = nil if label.blank?
  end

  def should_validate_from
    trade? || transfer? || withdrawal?
  end

  def should_validate_to
    trade? || transfer? || deposit?
  end

  def should_validate_fee
    fee_account_id.present?
  end

  def ensure_label_is_valid
    labels = CRYPTO_DEPOSIT_LABELS if crypto_deposit?
    labels = CRYPTO_WITHDRAWAL_LABELS if crypto_withdrawal?
    labels = FIAT_WITHDRAWAL_LABELS if fiat_withdrawal?
    labels = FIAT_DEPOSIT_LABELS if fiat_deposit?
    labels = TRADE_LABELS if trade?

    if label && labels && !labels.include?(label)
      errors.add(:label, "must be one of: #{labels.join(', ')}")
    end
  end

  def ensure_valid_transfer
    if from_amount.zero?
      errors.add(:from_amount, "must be more than 0")
    elsif to_amount.zero?
      errors.add(:to_amount, "must be more than 0")
    elsif to_amount > from_amount + 0.0000_0001
      # sometimes from_amount might have more than 8 decimals while the receiving wallet rounds
      # it to 8 so it looks like you received more than you sent. The TransferMatcher can
      # still match such txns so need to prevent any validation errors due to this here
      errors.add(:to_amount, "must be less than From_amount")
    elsif from_currency_id != to_currency_id
      errors.add(:from_currency_id, "must be same as To currency")
    end
  end

  # note: if this is called in an after_update we need to change all methods
  # to saved_change_to_transaction_type? instead of transaction_type_changed?
  def nullify_cost_basis
    return unless transaction_type_changed? ||
      net_value_changed? ||
      fee_value_changed? ||
      from_amount_changed? ||
      from_currency_id_changed? ||
      to_amount_changed? ||
      to_currency_id_changed? ||
      fee_amount_changed? ||
      fee_currency_id_changed? ||
      label_changed? ||
      ignored_changed? ||
      date_changed?

    self.gain = self.from_cost_basis = self.to_cost_basis = nil
  end
end
