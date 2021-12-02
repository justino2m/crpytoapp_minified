class AddPriorityToWalletServices < ActiveRecord::Migration[5.2]
  def change
    add_column :wallet_services, :priority, :integer, default: 0, null: false
  end
end
