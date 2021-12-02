class CreateCoupons < ActiveRecord::Migration[5.2]
  def change
    create_table :coupons do |t|
      t.references :owner, foreign_key: { to_table: :users }
      t.string :code, null: false
      t.string :type, null: false
      t.jsonb :rules
      t.integer :usages, default: 0, null: false
      t.datetime :expires_at

      t.timestamps
    end

    add_index :coupons, :code, unique: true
  end
end
