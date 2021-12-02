class RenameExternalIdToTxhashOnTransactions < ActiveRecord::Migration[5.2]
  def change
    rename_column :transactions, :external_id, :txhash
    remove_column :transactions, :external_data
    Entry.where.not(external_data: nil).update_all(synced: true)
    Entry.where(synced: true).includes(:txn).find_each { |entry| entry.txn.update_columns(synced: true) unless entry.txn.synced? }
  end
end
