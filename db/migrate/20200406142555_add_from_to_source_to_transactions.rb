class AddFromToSourceToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :from_source, :string
    add_column :transactions, :to_source, :string
  end
end
