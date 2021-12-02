class AddIndicesToPopularTableQueries < ActiveRecord::Migration[5.2]
  def change
    add_index :entries, :external_id
    add_index :entries, [:account_id, :external_id]
    add_index :transactions, [:user_id, :transaction_type, :from_account_id, :to_account_id, :txhash], name: 'index_transactions_on_user_id_type_txhash_etc'
    add_index :currencies, :symbol
    add_index :currencies, [:priority, :symbol]
  end
end
