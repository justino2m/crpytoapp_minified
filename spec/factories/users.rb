FactoryBot.define do
  factory :user do
    sequence(:name) { |s| "user_#{s}" }
    sequence(:email) { |s| "user_#{s}@example.com" }
    password "hello123"
    base_currency { Currency.usd || association(:usd) }
    display_currency { Currency.usd || association(:usd) }
    country { Country.usa || association(:country) }
    timezone 'UTC'

    factory :user2 do
      name "NewUser"
    end
  end
end
