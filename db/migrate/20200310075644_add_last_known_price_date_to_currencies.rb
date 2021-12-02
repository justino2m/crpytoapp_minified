class AddLastKnownPriceDateToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :last_known_price_date, :datetime
  end
end
