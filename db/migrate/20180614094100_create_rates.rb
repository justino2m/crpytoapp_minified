class CreateRates < ActiveRecord::Migration[5.2]
  def change
    create_table :rates do |t|
      t.references :currency, foreign_key: true, null: false
      t.decimal :quoted_rate, null: false, precision: 25, scale: 10
      t.datetime :date, null: false

      t.timestamps
    end

    add_index :rates, [:currency_id, :date], unique: true
  end
end
