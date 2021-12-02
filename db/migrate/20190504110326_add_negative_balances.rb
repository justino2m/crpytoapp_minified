class AddNegativeBalances < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :balance, :decimal, precision: 25, scale: 10
    add_column :transactions, :negative_balances, :boolean, default: false, null: false
  end
end
