class CapitalGainsReport < Report
  def generate
    analytics.capital_gains_disposals.map do |row|
      holding_period = row[:long_term] ? 'Long term' : 'Short term'
      [
        display_date(row[:sold_on]),
        display_date(row[:acquired_on]),
        row[:symbol],
        display_crypto(row[:amount]),
        display_base(row[:buying_price], false),
        display_base(row[:selling_price], false),
        display_base(row[:gain], false),
        row[:notes],
      ] + (user.country.has_long_term? ? [holding_period] : [])
    end
  end

  def prepare_report(rows)
    [["Capital gains report #{year}"], [], headers] + rows
  end

  def headers
    [
      "Date Sold",
      "Date Acquired",
      "Asset",
      "Amount",
      "Cost (#{user.base_currency.symbol})",
      "Proceeds (#{user.base_currency.symbol})",
      "Gain / loss",
      "Notes",
    ] + (user.country.has_long_term? ? ["Holding period"] : [])
  end
end
