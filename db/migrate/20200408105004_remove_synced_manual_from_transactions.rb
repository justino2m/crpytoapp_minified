class RemoveSyncedManualFromTransactions < ActiveRecord::Migration[5.2]
  def change
    remove_column :transactions, :synced
    remove_column :transactions, :manual
  end
end
