class CreateInvestments < ActiveRecord::Migration[5.2]
  def change
    create_table :investments do |t|
      t.references :user, foreign_key: true, null: false
      t.references :transaction, foreign_key: true, null: true
      t.references :account, foreign_key: true, null: true
      t.references :currency, foreign_key: true, null: false
      t.string :investment_type, null: false
      t.string :scope, null: false
      t.boolean :fee, null: false, default: false
      t.decimal :amount, null: false, precision: 25, scale: 10
      t.decimal :value, null: false, precision: 25, scale: 10
      t.decimal :gain, null: false, default: 0, precision: 25, scale: 10
      t.jsonb :metadata
      t.boolean :can_extract, null: false, default: false
      t.datetime :date, null: false
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
