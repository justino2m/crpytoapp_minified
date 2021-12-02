FactoryBot.define do
  factory :currency do
    sequence(:symbol) do |n|
      currencies = %w(BTC ETH LTC XRP XLM)
      currencies[n % currencies.length]
    end
    name "Coin"

    factory :usd do
      symbol 'USD'
      name 'US Dollar'
      fiat true

      after(:create) do |currency, evaluator|
        raise "the currency #{currency.symbol} already exists!" if Currency.where(fiat: currency.fiat, symbol: currency.symbol).count > 1
      end
    end

    factory :eur do
      symbol 'EUR'
      name 'Euro'
      fiat true
    end

    factory :btc do
      symbol 'BTC'
      name 'Bitcoin'
    end

    factory :eth do
      symbol 'ETH'
      name 'Ether'
    end

    factory :bnb do
      symbol 'BNB'
      name 'Binance Coin'
    end

    factory :crypto do
      name { symbol }
    end
  end

end
