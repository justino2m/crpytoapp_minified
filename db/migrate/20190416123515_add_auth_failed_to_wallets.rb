class AddAuthFailedToWallets < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :auth_failed, :boolean, null: false, default: false
  end
end
