class AddsStablecoinToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :stablecoin, :boolean, default: false, null: false
  end
end
