class AddExternalIdToWallets < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :external_id, :string
  end
end
