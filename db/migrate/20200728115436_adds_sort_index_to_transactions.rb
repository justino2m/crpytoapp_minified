class AddsSortIndexToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :sort_index, :integer
    change_column_default :transactions, :sort_index, from: nil, to: 0
  end
end
