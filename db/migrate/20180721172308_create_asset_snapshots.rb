class CreateAssetSnapshots < ActiveRecord::Migration[5.2]
  def change
    create_table :asset_snapshots do |t|
      t.references :user, foreign_key: true, null: false
      t.references :asset, foreign_key: true, null: false
      t.references :currency, foreign_key: true, null: false
      t.decimal :total_amount, null: false, default: 0, precision: 25, scale: 10
      t.decimal :total_worth, null: false, default: 0, precision: 25, scale: 10
      t.decimal :invested_value, null: false, default: 0, precision: 25, scale: 10
      t.decimal :gains, null: false, default: 0, precision: 25, scale: 10
      t.datetime :date, null: false

      t.timestamps
    end
  end
end
