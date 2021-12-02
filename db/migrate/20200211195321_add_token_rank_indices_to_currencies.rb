class AddTokenRankIndicesToCurrencies < ActiveRecord::Migration[5.2]
  def change
    remove_index :currencies, [:priority, :symbol]
    remove_index :currencies, [:priority]
    add_index :currencies, [:priority, :rank]
    add_index :currencies, :platform_id
    # remove_index :transactions, :index_transactions_on_user_id_type_txhash_etc
    # add_index :transactions, [:user_id, :type, :group_name, :group_date], :index_transactions_on_user_groups
    # add_index :transactions, [:user_id, :type], :index_transactions_on_txhash
    # add_index :transactions, [:user_id, :date], :index_transactions_on_date
  end
end
