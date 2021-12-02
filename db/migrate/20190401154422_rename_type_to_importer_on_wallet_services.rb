class RenameTypeToImporterOnWalletServices < ActiveRecord::Migration[5.2]
  def change
    rename_column :wallet_services, :type, :importer
    rename_column :wallet_services, :external_data, :options
    remove_column :wallet_services, :external_id

    WalletService.where(importer: 'DummyWallet').destroy_all
    WalletService.all.each do |svc|
      if svc.importer == 'AltcoinWallet'
        svc.options[:blockchain] = svc.currency.symbol.downcase
      end
      svc.importer.gsub!('Wallet', 'Importer')
      svc.save!
    end
    Wallet.where.not(wallet_service_id: nil).each do |wallet|
      if wallet.metadata[:public_address]
        wallet.metadata[:address] = wallet.metadata.delete(:public_address)
      end
      raise "still invalid: #{wallet.id}" unless wallet.valid?
      wallet.save!
    end
  end
end
