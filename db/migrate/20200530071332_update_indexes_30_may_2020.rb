class UpdateIndexes30May2020 < ActiveRecord::Migration[5.2]
  def change
    remove_index :investments, :amount
    remove_index :assets, :currency_id
    remove_index :users, :display_currency_id
    add_index :currencies, :cmc_id
    add_index :transactions, :from_wallet_id
    add_index :transactions, :to_wallet_id
  end
end
