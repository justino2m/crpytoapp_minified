class AddRebuildScheduledToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :rebuild_scheduled, :boolean, default: false, null: false
  end
end
