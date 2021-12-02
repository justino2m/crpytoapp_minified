FactoryBot.define do
  factory :subscription do
    user { association(:user) }
    plan { association(:plan) }
    amount_paid 100
    max_txns 1000
    expires_at 1.year.from_now
  end
end
