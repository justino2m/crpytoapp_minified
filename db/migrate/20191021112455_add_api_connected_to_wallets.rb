class AddApiConnectedToWallets < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :api_connected, :boolean, default: false, null: false
    rename_column :wallets, :syncdata, :api_syncdata
    rename_column :wallets, :metadata, :api_options
    # Wallet.where.not(wallet_service_id: nil).update_all(api_connected: true)
    # WalletService.find_by(api_importer: 'IdexImporter').wallets.each do |wallet|
    #   wallet.api_options[:address] = wallet.api_options.delete(:wallet_address)
    #   wallet.save!
    # end
  end
end
