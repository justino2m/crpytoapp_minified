class UpdateIndexesOnInvestments < ActiveRecord::Migration[5.2]
  def change
    remove_index :investments, :extracted_amount
    remove_index :investments, :transaction_id
    add_index :investments, [:user_id, :transaction_id]
    add_index :investments, [:user_id, :currency_id]
    add_index :investments, [:user_id, :account_id]
    add_index :entries, [:account_id, :transaction_id, :date]
    remove_index :transactions, :from_currency_id
    remove_index :transactions, :to_currency_id
    remove_index :transactions, :fee_currency_id
    remove_index :transactions, :net_worth_currency_id
    remove_index :transactions, :fee_worth_currency_id
    add_index :transactions, [:user_id, :from_currency_id]
    add_index :transactions, [:user_id, :to_currency_id]
    add_index :transactions, [:user_id, :fee_currency_id]
    remove_index :currencies, [:priority, :rank]
  end
end
