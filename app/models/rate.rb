class Rate < ApplicationRecord
  belongs_to :currency
  validates_presence_of :date
  validates_numericality_of :quoted_rate
  serialize :hourly_rates, HashSerializer

  # NOTE: rate is the quoted rate i.e if currency is ETH then rate will
  # be how many USD are equal to 1 ETH. ETH here is the base currency
  # and USD is the quote currency.
  def self.fetch_rate(from_currency, to_currency, date)
    return 0 if from_currency.nil? || to_currency.nil?

    # resolve stablecoins
    from_currency = from_currency.stablecoin if from_currency.stablecoin?
    to_currency = to_currency.stablecoin if to_currency.stablecoin?

    return 1 if from_currency == to_currency

    if from_currency == Currency.usd
      rate = Rate.
        where(currency: to_currency).
        where('date <= ?', date).
        order(date: :desc).
        first
      if rate
        hr = rate.hourly_rate(date.hour)
        return 0 if hr.zero?
        return 1 / hr
      end
    elsif to_currency == Currency.usd
      rate = Rate.
        where(currency: from_currency).
        where('date <= ?', date).
        order(date: :desc).
        first
      return rate.hourly_rate(date.hour) if rate
    else
      return fetch_rate(from_currency, Currency.usd, date) *
        fetch_rate(Currency.usd, to_currency, date)
    end

    0
  end

  def self.convert_amount(from_amount, from_currency, to_currency, date)
    from_amount * fetch_rate(from_currency, to_currency, date)
  end

  def self.build_rate(currency, date:, price:, volume:, source: 'cmc', rate: nil)
    rate ||= currency.rates
      .where('date >= ?', date.beginning_of_day)
      .where('date < ?', date.end_of_day)
      .order(date: :asc)
      .first_or_initialize(date: date, source: source)

    rate.volume = volume
    rate.quoted_rate = price
    rate.hourly_rates[date.strftime('%H').to_i] = price
    rate
  end

  def hourly_rate(hour)
    # rates before 29/4/2019 were stored in strings like: '01', '02', '23' etc
    hourly_rates.transform_keys!(&:to_i)
    h = hourly_rates.keys.sort.reverse.find{ |h| h <= hour }
    h ? hourly_rates[h].to_d : quoted_rate
  end
end
