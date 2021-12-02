class AddSourceToRates < ActiveRecord::Migration[5.2]
  def change
    add_column :rates, :source, :string
    # ids = Currency.where.not(external_id: nil).pluck :id
    # Rate.where(currency_id: ids).where.not(hourly_rates: nil).update_all(source: 'cmc')
    # Rate.where(currency_id: ids).where(hourly_rates: nil).update_all(source: 'crypto_compare')
  end
end
