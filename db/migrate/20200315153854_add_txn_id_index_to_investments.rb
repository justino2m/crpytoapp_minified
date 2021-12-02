class AddTxnIdIndexToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_index :investments, :transaction_id
  end
end
