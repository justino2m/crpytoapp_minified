class Account < ApplicationRecord
  belongs_to :user
  belongs_to :wallet
  belongs_to :currency

  before_destroy :cleanup_associations
  has_many :investments, dependent: :nullify
  has_many :entries, dependent: :delete_all
  has_many :from_txns, class_name: Transaction.to_s, foreign_key: :from_account_id
  has_many :to_txns, class_name: Transaction.to_s, foreign_key: :to_account_id
  has_many :fee_txns, class_name: Transaction.to_s, foreign_key: :fee_account_id

  validates_numericality_of :balance

  def txns
    Transaction.by_account_id(id)
  end

  def update_totals
    self.balance = entries.not_deleted.sum(:amount)
    self.fees = entries.not_deleted.fees.sum(:amount).abs
  end

  def update_totals!
    update_totals
    save! if changed?
  end

  private

  def cleanup_associations
    # an account should only be deleted as part of its wallet's deletion so
    # we have to unmerge 'transfers' as they can occur between 2 wallets.
    txns
      .where(type: Transaction::TRANSFER)
      .find_each{ |txn| ActiveRecord::Base.transaction { txn.unmerge_partially!(id) } }

    # 'exchange' txns might still have references from entries in another account
    # so we will delete txns when all accounts are gone in AccountsUpdater
    txns.update_all(from_account_id: nil, to_account_id: nil, fee_account_id: nil)
  end
end
