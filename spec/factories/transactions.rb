FactoryBot.define do
  factory :transaction do
    user
    transaction_type "crypto_deposit"
    to_currency { Currency.find_by(symbol: 'BTC') || association(:btc) }
    to_account { association(:account, user: user, currency: to_currency) }
    to_amount 10
    net_value 10000
    fee_value 0
    label Transaction::AIRDROP
    date "2018-06-19 06:42:53"

    after(:create) do |txn|
      create(:entry, txn: txn)
    end
  end

  factory :withdrawal, class: Transaction do
    user
    transaction_type "crypto_withdrawal"
    from_currency { Currency.find_by(symbol: 'BTC') || association(:btc) }
    from_account { association(:account, user: user, currency: from_currency) }
    from_amount 10
    date "2018-06-19 06:42:53"
  end

  factory :deposit, class: Transaction do
    user
    transaction_type "crypto_deposit"
    to_currency { Currency.find_by(symbol: 'BTC') || association(:btc) }
    to_account { association(:account, user: user, currency: to_currency) }
    to_amount 10
    date "2018-06-19 06:42:53"
  end
end
