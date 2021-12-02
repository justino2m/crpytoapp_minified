class AddIndexOnCurrencySorting < ActiveRecord::Migration[5.2]
  def change
    add_index :currencies, :token_address
    add_index :currencies, :coingecko_id
    add_index :currencies, [:priority, :rank, :symbol], order: { priority: :desc, rank: :asc }
    remove_index :currencies, [:symbol]
    remove_index :currencies, name: :find_rates_index
  end
end
