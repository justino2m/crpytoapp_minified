class AddMarginToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :margin, :boolean
  end
end
