class RenameCryptoExchangeTag < ActiveRecord::Migration[5.2]
  def change
    WalletService.find_by(tag: 'crypto_exchange')&.update_columns tag: 'crypto_com', name: 'Crypto.com'
    Transaction.where(importer_tag: 'crypto_wallet').update_all importer_tag: 'crypto_com'
    Transaction.where(importer_tag: 'crypto_exchange').update_all importer_tag: 'crypto_com'
  end
end
