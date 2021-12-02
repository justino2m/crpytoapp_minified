class Investment < ApplicationRecord
  COST_BASIS_METHODS = [
    (FIFO = 'fifo'),
    (LIFO = 'lifo'),
    (HIFO = 'hifo'),
    (LOW_COST = 'low_cost'),
    (AVERAGE_COST = 'average_cost'),
    (FIFO_IRELAND = 'fifo_ireland'),
    (SHARED_POOL = 'shared_pool'),
    (SHARED_POOL2 = 'shared_pool2'),
    (SHARED_POOL_COMPANY = 'shared_pool_company'),
    (ACB_CANADA = 'acb_canada'),
    (PFU_FRANCE = 'pfu_france'),
  ].freeze

  SUBTYPES = [
    (FAILED = 'failed'),
    (WASH_SALE = 'wash_sale'),
    (EXTERNAL = 'external'),
    (FEE = 'fee'),
    (AMOUNT_ONLY_FEE = 'amount_only_fee'),
    (OWN_TRANSFER = 'own_transfer'), # this is an internal transfer and should be ignored in tax reports
    (OWN_TRANSFER_FEE = 'own_transfer_fee'), # same as above but for fees
  ]

  belongs_to :user
  belongs_to :txn, class_name: Transaction.to_s, foreign_key: :transaction_id, inverse_of: :investments
  belongs_to :account
  belongs_to :currency

  belongs_to :from, class_name: Investment.to_s
  has_many :to, class_name: Investment.to_s, foreign_key: :from_id

  scope :pending_deletion, -> { where('transaction_id IS NULL OR account_id IS NULL OR deleted_at IS NOT NULL') }
  scope :deposits, -> { where(deposit: true) }
  scope :withdrawals, -> { where(deposit: false) }
  scope :extractable, -> { deposits.where('extracted_amount < amount OR extracted_value < value').without_subtype([WASH_SALE, FAILED]) }
  scope :extraction_failed, -> { where(subtype: FAILED) }
  scope :external_gain, -> { where(subtype: EXTERNAL) }
  scope :without_subtype, ->(type) { where.not(subtype: type).or(where(subtype: nil)) }

  scope :ordered, -> { order(date: :asc, amount: :desc, id: :asc) }
  scope :reverse_ordered, -> { order(date: :desc, amount: :desc, id: :asc) } # only date can be reverse ordered, the rest are same

  # note: this ordering is directly tied to the order in which we loop over the transactions
  # in the BaseCalculator
  scope :earlier_than, ->(e) do
    if e.persisted?
      where('date < :date OR (date = :date AND id < :id)', date: e.date, id: e.id)
    else
      where('date <= ?', e.date)
    end
  end

  validates_presence_of :date
  validates_numericality_of :amount, :value

  serialize :metadata, HashSerializer

  # NOTE: we are soft deleting so that we can distinguish between deleted and non-deleted investments
  # in the investment_updater.delete_investments method
  def self.soft_delete!
    update_all(deleted_at: Time.now)
  end

  def withdrawal?
    !deposit?
  end

  def external?
    subtype == EXTERNAL
  end

  def failed?
    subtype == FAILED
  end

  def notes
    notes = []
    notes << pool_name.gsub('_', ' ').capitalize + (pool_name.include?('pool') ? '' : ' pool') if pool_name
    notes << case subtype
    when EXTERNAL
      "Margin trade"
    when FAILED
      "Missing cost basis"
    else
      subtype.gsub('_', ' ').capitalize
    end if subtype

    notes.join(', ')
  end

  def self.calculator_class(cost_basis_method)
    case cost_basis_method
    when Investment::FIFO
      Fifo
    when Investment::LIFO
      Lifo
    when Investment::HIFO
      HighestCost
    when Investment::LOW_COST
      LowestCost
    when Investment::AVERAGE_COST, Investment::ACB_CANADA
      AverageCost
    when Investment::FIFO_IRELAND
      Fifo
    else
      raise "unknown cost basis method: #{cost_basis_method}"
    end
  end
end
