class CreateCurrencies < ActiveRecord::Migration[5.2]
  def change
    create_table :currencies do |t|
      t.string :symbol, null: false
      t.string :name, null: false
      t.boolean :fiat, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :priority, null: false, default: 0
      t.attachment :icon
      t.datetime :synced_at
      t.jsonb :metadata
      t.string :external_id

      t.timestamps
    end
  end
end
