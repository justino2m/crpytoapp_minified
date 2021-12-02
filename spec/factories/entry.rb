FactoryBot.define do
  factory :entry do
    user
    account
    txn { association(:transaction) }
    amount 10
    fee false
    date "2018-06-19 06:42:53"
  end
end
