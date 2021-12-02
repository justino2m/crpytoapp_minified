class CreateLiveMarketRates < ActiveRecord::Migration[5.2]
  def change
    create_table :live_market_rates do |t|
      t.references :currency, foreign_key: true, null: false
      t.integer :rank
      t.decimal :price, default: 0, null: false
      t.integer :market_cap, limit: 8, default: 0, null: false
      t.integer :volume, limit: 8, default: 0, null: false
      t.jsonb :metadata
      t.datetime :synced_at

      t.timestamps
    end
  end
end
