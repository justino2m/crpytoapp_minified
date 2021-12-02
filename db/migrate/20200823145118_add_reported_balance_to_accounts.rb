class AddReportedBalanceToAccounts < ActiveRecord::Migration[5.2]
  def change
    add_column :accounts, :reported_balance, :decimal, precision: 25, scale: 10
  end
end
