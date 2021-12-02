FactoryBot.define do
  factory :wallet do
    user
    wallet_service nil
    name "Test Wallet"
    synced_at "2018-07-15 22:00:40"

    factory :wallet_with_account do
      after :create do |wallet|
        create :account, wallet: wallet, user: wallet.user
      end
    end
  end
end
