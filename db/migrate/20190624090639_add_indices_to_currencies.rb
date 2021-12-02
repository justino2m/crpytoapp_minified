class AddIndicesToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_index :currencies, :active
    add_index :currencies, :priority
    add_index :currencies, [:fiat, :symbol], name: 'find_rates_index'
    add_index :investments, :amount
    add_index :investments, :extracted_amount
    add_index :investments, :date
    add_index :investments, [:user_id, :amount, :extracted_amount, :currency_id, :date], name: 'deposits_index'
  end
end
