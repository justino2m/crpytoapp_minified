class CreatePayouts < ActiveRecord::Migration[5.2]
  def change
    create_table :payouts do |t|
      t.references :user, foreign_key: true
      t.decimal :amount, null: false, precision: 8, scale: 2
      t.string :description
      t.datetime :processed_at

      t.timestamps
    end
  end
end
