class CreateTransactions < ActiveRecord::Migration[5.2]
  def change
    create_table :transactions do |t|
      t.string :transaction_type, null: false
      t.references :user, foreign_key: true, null: false
      t.references :from_account, foreign_key: { to_table: :accounts }
      t.references :to_account, foreign_key: { to_table: :accounts }
      t.references :fee_account, foreign_key: { to_table: :accounts }
      t.references :from_currency, foreign_key: { to_table: :currencies }
      t.references :to_currency, foreign_key: { to_table: :currencies }
      t.references :fee_currency, foreign_key: { to_table: :currencies }
      t.decimal :from_amount, null: false, precision: 25, scale: 10, default: 0
      t.decimal :to_amount, null: false, precision: 25, scale: 10, default: 0
      t.decimal :fee_amount, null: false, precision: 25, scale: 10, default: 0
      t.decimal :net_value, null: false, precision: 25, scale: 10, default: 0
      t.decimal :fee_value, null: false, precision: 25, scale: 10, default: 0
      t.string :label
      t.text :description
      t.jsonb :metadata
      t.string :external_id
      t.jsonb :external_data
      t.datetime :started_at, null: false
      t.datetime :completed_at, null: false

      t.timestamps
    end
  end
end
