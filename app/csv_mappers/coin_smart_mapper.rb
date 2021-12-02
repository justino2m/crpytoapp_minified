class CoinSmartMapper < BaseMapper
  tag Tag::COINSMART
  mappings [
    {
      id: 'coin-smart-transactions',
      determine_date_format: true,
      required_headers: ['Credit', 'Debit', 'Transaction type', 'Reference Type', 'Product', 'Balance', 'Time Stamp'],
      header_mappings: {
        date: 'Time Stamp',
        amount: 'Balance',
        currency: 'Product'
      },
      group: {
        eligible: ->(mapped, row) { row['Reference Type'].match(/Withdraw|Deposit|Trade/) },
      }
    }
  ]

  def fetch_rows(headers, spreadsheet)
    @amount_header = headers.find { |header| header.match(/Balance \(\w+\)/) }
    @currency = @amount_header.match(/Balance \((\w+)\)/)[1]
    super
  end

  def parse_row(mapped_row, raw_row, _)
    mapped_row[:net_worth_amount] = raw_row[@amount_header]
    mapped_row[:net_worth_currency] = @currency

    case raw_row['Reference Type'].downcase
    when 'Withdraw'
      mapped_row[:amount] = -mapped_row[:amount].clean_d
      # override the net worth of 'sell' with the buys worth
      mapped_row[:net_worth_amount] = mapped_row[:net_worth_currency] = nil if raw_row['Reference Type'] == 'Withdraw'
    when 'Deposit', 'Trade'
    else
      mapped_row.merge!(error: log_error("unknown coinsmart txn type #{raw_row['Reference Type']}"))
    end
    mapped_row
  end
end
