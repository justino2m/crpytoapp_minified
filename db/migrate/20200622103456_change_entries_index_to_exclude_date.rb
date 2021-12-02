class ChangeEntriesIndexToExcludeDate < ActiveRecord::Migration[5.2]
  def change
    remove_index :entries, [:account_id, :transaction_id, :date]
    add_index :entries, [:account_id, :transaction_id]
  end
end
