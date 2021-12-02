class CreateSnapshots < ActiveRecord::Migration[5.2]
  def change
    create_table :snapshots do |t|
      t.references :user, foreign_key: true, null: false
      t.decimal :total_worth, default: 0, null: false, precision: 25, scale: 10
      t.decimal :invested, default: 0, null: false, precision: 25, scale: 10
      t.decimal :gains, default: 0, null: false, precision: 25, scale: 10
      t.jsonb :worths
      t.datetime :date, null: false

      t.timestamps
    end

    add_index :snapshots, [:user_id, :date], unique: true
  end
end
