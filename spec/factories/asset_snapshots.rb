FactoryBot.define do
  factory :asset_snapshot do
    user
    asset { association(:asset, user: user) }
    currency
    total_amount "9.99"
    total_worth "20"
    invested_amount "9.99"
    date "2018-07-21 19:23:08"
  end
end
