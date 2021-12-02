class CreatePermaLocks < ActiveRecord::Migration[5.2]
  def change
    create_table :perma_locks do |t|
      t.string :name, null: false
      t.jsonb :metadata
      t.datetime :stale_at, null: false

      t.timestamps null: false
    end

    add_index :perma_locks, :name, unique: true
  end
end
