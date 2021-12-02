module TxnValueCalculator
  # priority: to/from > net_worth > fiat > stablecoin > market
  def calculate_net_value
    pick_first_value [
      ->{ to_amount if to_amount && to_currency_id == user.base_currency_id },
      ->{ from_amount if from_amount && from_currency_id == user.base_currency_id },

      ->{ convert_from_market_rate(net_worth_amount, net_worth_currency, date) },

      # try to convert fiat amounts
      ->{ convert_from_market_rate(to_amount, to_currency, date) if to_currency&.fiat? },
      ->{ convert_from_market_rate(from_amount, from_currency, date) if from_currency&.fiat? },

      # stablecoins should not be given same prio as fiats, for ex. if you pay 120 USD for 100 USDT (and base currency is SEK) then value of txn should be 120
      ->{ convert_from_market_rate(to_amount, to_currency, date) if to_currency&.stablecoin? },
      ->{ convert_from_market_rate(from_amount, from_currency, date) if from_currency&.stablecoin? },

      # finally we convert directly from crypto to fiat, preferring value of to_amount over from_amount.
      # ex. if we trade 2 ETH for 2000 LTC, we want 2000 LTC's market value not 2 ETH's
      ->{ convert_from_market_rate(to_amount, to_currency, date) },
      ->{ convert_from_market_rate(from_amount, from_currency, date) },
    ]
  end

  # note: this uses net_value so ensure it is set by calling above method before calling it
  def calculate_fee_value
    pick_first_value [
      ->{ 0 unless fee? },
      ->{ fee_amount if fee_currency_id == user.base_currency_id },

      # convert from fee-worth - this takes prio over the to/from conversions so users can easily set fee worth to 0 when needed
      ->{ convert_from_market_rate(fee_worth_amount, fee_worth_currency, date) },

      # if from/to currencies are same as fee currency and we can use net-value to calc the fee value
      ->{ fee_amount * net_value / to_amount if to_amount && to_currency_id == fee_currency_id },
      ->{ fee_amount * net_value / from_amount if from_amount && from_currency_id == fee_currency_id },

      # calculate from market data
      ->{ convert_from_market_rate(fee_amount, fee_currency, date) }
    ]
  end

  def pick_first_value(procs)
    procs.detect do |proc|
      value = instance_exec(&proc)
      return value if value.present?
    end
  end

  # we are storing all rates locally to ensure transaction data doesnt change accidentally
  # just because we called update_totals. the rates table is subject to changes that should
  # not be automatically reflected in old transactions.
  # each rate is equal to the value of 1 XYZ in user's base currency, ex:
  #   { 'SEK' => { 'XYZ' => 123 } } -> the first key is the users base currency, this allows quick switching
  def convert_from_market_rate(amount, currency, date)
    return unless amount && currency
    return amount if currency == user.base_currency

    # retrieve from local cache
    rate = cached_rates.dig(user.base_currency.symbol, currency.symbol)
    return nil if rate == false # avoids unnecessary queries

    # fetch from market data if dont have a cached rate
    unless rate.present?
      rate = Rate.fetch_rate(currency, user.base_currency, date)
      cached_rates[user.base_currency.symbol] ||= {}
      cached_rates[user.base_currency.symbol][currency.symbol] = rate > 0 ? rate : false
      return nil if rate.zero?
    end

    rate.to_d * amount
  end
end
