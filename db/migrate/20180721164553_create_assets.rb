class CreateAssets < ActiveRecord::Migration[5.2]
  def change
    create_table :assets do |t|
      t.references :user, foreign_key: true, null: false
      t.references :currency, foreign_key: true, null: false
      t.decimal :total_amount, null: false, default: 0, precision: 25, scale: 10
      t.decimal :fee_amount, null: false, default: 0, precision: 25, scale: 10
      t.decimal :invested_amount, null: false, default: 0, precision: 25, scale: 10
      t.jsonb :stats

      t.timestamps
    end

    add_index :assets, [:user_id, :currency_id], unique: true
  end
end
