class CreatePlans < ActiveRecord::Migration[5.2]
  def change
    create_table :plans do |t|
      t.string :name, null: false
      t.integer :max_txns, null: false
      t.integer :price_cents, null: false

      t.timestamps
    end
  end
end
