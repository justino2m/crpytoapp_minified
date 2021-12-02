FactoryBot.define do
  factory :asset do
    user
    currency
    total_amount "1000"
    invested_amount "20"
    stats {}
  end
end
