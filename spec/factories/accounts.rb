FactoryBot.define do
  factory :account do
    user
    wallet { association(:wallet, user: user) }
    currency
    balance 0
    fees 0
  end
end
