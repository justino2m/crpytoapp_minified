class AddIndexToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_index :transactions, [:user_id, :id, :date]
    add_index :transactions, [:from_account_id, :to_account_id, :fee_account_id], name: 'account_transactions'
    remove_index :transactions, [:user_id]
  end
end
