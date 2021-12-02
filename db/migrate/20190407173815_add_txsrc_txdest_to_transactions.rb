class AddTxsrcTxdestToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :txsrc, :string
    add_column :transactions, :txdest, :string
    add_column :transactions, :importer_tag, :string
  end
end
