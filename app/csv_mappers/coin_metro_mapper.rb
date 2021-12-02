class CoinMetroMapper < BaseMapper
  tag Tag::COINMETRO
  mappings [
    {
      id: 'coin-metro-transactions',
      determine_date_format: true,
      required_headers: ['Currency', 'Date', 'Description', 'Amount', 'Fees', 'Price', 'Pair', 'Other Currency', 'Other Amount'],
      header_mappings: {
        date: 'Date',
        amount: 'Amount',
        currency: 'Currency',
        description: 'Description',
        fee_amount: 'Fees',
        pair: 'Pair'
      }
    }
  ]
end
