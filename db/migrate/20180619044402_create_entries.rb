class CreateEntries < ActiveRecord::Migration[5.2]
  def change
    create_table :entries do |t|
      t.references :user, foreign_key: true, null: false
      t.references :transaction, foreign_key: true, null: false
      t.references :account, foreign_key: true, null: false
      t.decimal :amount, null: false, precision: 25, scale: 10
      t.boolean :fee, null: false, default: false
      t.string :external_id
      t.jsonb :external_data
      t.datetime :date, null: false

      t.timestamps
    end
  end
end
