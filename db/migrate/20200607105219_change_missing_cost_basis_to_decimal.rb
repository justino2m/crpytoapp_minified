class ChangeMissingCostBasisToDecimal < ActiveRecord::Migration[5.2]
  def change
    remove_column :transactions, :missing_cost_basis
    add_column :transactions, :missing_cost_basis, :decimal, precision: 12, scale: 2
  end
end
