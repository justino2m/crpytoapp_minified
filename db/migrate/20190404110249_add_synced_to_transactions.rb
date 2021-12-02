class AddSyncedToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :synced, :boolean, null: false, default: false
  end
end
