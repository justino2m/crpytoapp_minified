class AddCostBasisMethodToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :cost_basis_method, :string, default: 'fifo', null: false
  end
end
