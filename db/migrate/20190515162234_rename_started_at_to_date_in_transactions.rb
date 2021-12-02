class RenameStartedAtToDateInTransactions < ActiveRecord::Migration[5.2]
  def change
    rename_column :transactions, :started_at, :date
    remove_column :transactions, :completed_at
  end
end
