class AddCoingeckoIdToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :coingecko_id, :string
    add_column :currencies, :price_source, :string
    rename_column :currencies, :external_id, :cmc_id
  end
end
