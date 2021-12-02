class ClearSyncdataForOldChainzImporters < ActiveRecord::Migration[5.2]
  def change
    WalletService.where(tag: [Tag::BTC, Tag::BCH, Tag::DASH, Tag::LTC]).each do |service|
      service.wallets.map{ |x| x.update_attributes!(api_syncdata: nil) }
    end
  end
end
