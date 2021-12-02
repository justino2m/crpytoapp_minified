class LiveMarketRate < ApplicationRecord
  belongs_to :currency
  serialize :metadata, HashSerializer
  store_accessor :metadata, :recent_rates, :volume, :market_cap, :circulating_supply, :change1h, :change1d, :change7d

  # returns array of ints with data ordered oldest to newest
  def sparkline
    return [] unless recent_rates
    recent_rates.map { |r| r['rate'].to_d }.reverse
  end

  def add_recent_rate(date, rate)
    self.recent_rates ||= []
    self.recent_rates.unshift('date' => date, 'rate' => rate)
    self.recent_rates.pop if recent_rates.count > 24
  end
end
