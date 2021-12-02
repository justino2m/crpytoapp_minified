class MergeLiveMarketRatesIntoCurrency < ActiveRecord::Migration[5.2]
  def change
    drop_table :live_market_rates
    add_column :currencies, :rank, :integer
    add_column :currencies, :price, :decimal
    add_column :currencies, :market_data, :jsonb
    rename_column :currencies, :metadata, :external_data
    Currency.crypto.update_all(priority: 0)
    # SyncCmcPrices.call(true)
    # SyncFiatRates.call
  end
end
