FactoryBot.define do
  factory :country do
    name "United States"
    code "USA"
    currency { Currency.usd || association(:usd) }
    metadata nil
  end

  factory :sweden do
    name "Sweden"
    code "SWE"
    currency { association(:eur) }
    metadata nil
  end
end
