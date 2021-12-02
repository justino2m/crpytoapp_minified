FactoryBot.define do
  factory :wallet_service, class: WalletService do
    name "Wallet Service"
    tag "base"
    api_importer BaseImporter
  end
end
