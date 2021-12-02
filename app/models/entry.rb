class Entry < ApplicationRecord
  belongs_to :user
  belongs_to :account
  belongs_to :txn, class_name: Transaction.to_s, foreign_key: :transaction_id, inverse_of: :entries

  scope :fees, -> { where(fee: true) }
  scope :pending_deletion, -> { where(transaction_id: nil) }
  scope :pending_balance, -> { where('balance IS NULL OR transaction_id IS NULL') }
  scope :not_deleted, -> { where.not(transaction_id: nil) }
  scope :not_ignored, -> { where(ignored: false) }
  scope :ignored, -> { where(ignored: true) }

  # sort by date first (lowest to highest), then by amount (highest to lowest) then by id (lowest to highest)
  # this allows us to handle entries on the dame date ex. you can have a deposit and a withdrawal at the same time
  # on coinbase, without the amount check we would get negative balances as the withdrawal's id could be lower
  # than the deposit's. Prioritizing by amount allows to handle this case.
  scope :ordered, -> { order(date: :asc, amount: :desc, id: :asc) }
  scope :reverse_ordered, -> { order(date: :desc, amount: :asc, id: :desc) }
  scope :earlier_than, ->(e) { ordered.where('date < :date OR (date = :date AND amount > :amount) OR (date = :date AND amount = :amount AND id < :id)', date: e.date, amount: e.amount, id: e.id) }

  before_validation -> { self.user ||= txn.user }
  validates_numericality_of :amount
  validates_presence_of :date
  before_update -> { self.balance = nil if amount_changed? || date_changed? }

  # NOTE: entries should always be soft deleted so that subsequent balances can be correctly updated
  def self.soft_delete!
    update_all(transaction_id: nil)
  end

  def self.ignore!
    update_all(ignored: true, balance: nil, negative: false)
  end

  def self.unignore!
    update_all(ignored: false, balance: nil, negative: false)
  end
end
