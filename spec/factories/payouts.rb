FactoryBot.define do
  factory :payout do
    user { association(:user) }
    amount 10
    description "send to paypal"
  end
end
