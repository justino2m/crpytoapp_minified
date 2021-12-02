class AddMissingCostBasisToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :missing_cost_basis, :boolean, null: false, default: false
  end
end
