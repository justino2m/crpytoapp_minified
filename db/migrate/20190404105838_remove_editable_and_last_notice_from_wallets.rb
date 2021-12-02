class RemoveEditableAndLastNoticeFromWallets < ActiveRecord::Migration[5.2]
  def change
    remove_column :wallets, :last_notice
    remove_column :wallets, :editable
    remove_column :wallet_services, :editable_wallets
  end
end
