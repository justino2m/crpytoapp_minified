class AddSyncedToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :synced, :boolean, null: false, default: false
  end
end
