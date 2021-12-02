class AddCostBasisToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :from_cost_basis, :decimal, precision: 25, scale: 10
    add_column :transactions, :to_cost_basis, :decimal, precision: 25, scale: 10
    add_column :transactions, :gain, :decimal, precision: 25, scale: 10
  end
end
