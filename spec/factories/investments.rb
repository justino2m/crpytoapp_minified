FactoryBot.define do
  factory :investment do
    user
    transaction { association(:transaction, user: user) }
    account { association(:account, user: user) }
    amount "9.99"
    gain "9.99"
    investment_type "Withdrawal"
    date "2018-07-18 12:28:29"
  end
end
