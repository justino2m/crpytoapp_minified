class Asset < ApplicationRecord
  belongs_to :user
  belongs_to :currency

  validates_numericality_of :total_amount, :total_reported_amount, :invested_amount

  delegate :crypto?, :fiat?, to: :currency

  def update_totals
    accounts = user.accounts.where(currency_id: currency_id).to_a
    self.total_amount = accounts.select{ |acc| acc.balance > 0 }.sum(&:balance).round(8)
    self.total_reported_amount = sum_reported_balances(accounts).round(8)

    investments = user.investments.where(currency_id: currency_id)
    self.invested_amount = (investments.deposits.sum(:value) - investments.withdrawals.sum(:value)).round(2)
  end

  def update_totals!
    update_totals
    save! if changed?
  end

  private

  def sum_reported_balances(accounts)
    accounts.map do |account|
      if account.reported_balance.nil?
        account.balance
      elsif account.reported_balance > 0.0001 && account.balance >= 0 && account.balance <= 0.0001 && account.entries.ignored.exists?
        # sometimes users will remove certain txns to get rid of coins they dont want to see on their dashboard,
        # we should ignore the reported balance in such cases
        account.balance
      else
        account.reported_balance
      end
    end.select{ |amount| amount > 0 }.sum
  end
end
