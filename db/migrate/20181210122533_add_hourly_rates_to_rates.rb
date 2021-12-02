class AddHourlyRatesToRates < ActiveRecord::Migration[5.2]
  def change
    add_column :rates, :hourly_rates, :jsonb
  end
end
