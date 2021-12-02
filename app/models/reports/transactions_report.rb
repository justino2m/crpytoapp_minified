class TransactionsReport < Report
  def generate
    rows = []
    analytics.ordered_transactions.pluck(:id).each_slice(100).map do |chunked_ids|
      Transaction.where(id: chunked_ids).order(date: :asc).map do |txn|
        rows << row(txn).map(&:to_s)
      end
    end
    rows
  end

  def prepare_report(rows)
    [["Transaction report #{year}"], [], headers] + rows
  end

  def headers
    [
      "Date",
      "Type",
      "Label",
      "Sending Wallet",
      "Sent Amount",
      "Sent Currency",
      "Sent Cost Basis",
      "Receiving Wallet",
      "Received Amount",
      "Received Currency",
      "Received Cost Basis",
      "Fee Amount",
      "Fee Currency",
      "Gain (#{user.base_currency.symbol})",
      "Net Value (#{user.base_currency.symbol})",
      "Fee Value (#{user.base_currency.symbol})",
      "Description"
    ]
  end

  private

  def row(txn)
    [
      txn.date,
      txn.type,
      txn.label,

      txn.from_account&.wallet&.name,
      blank_if_zero(txn.from_amount),
      txn.from_currency&.symbol,
      blank_if_zero(txn.from_cost_basis),

      txn.to_account&.wallet&.name,
      blank_if_zero(txn.to_amount),
      txn.to_currency&.symbol,
      blank_if_zero(txn.to_cost_basis),

      blank_if_zero(txn.fee_amount),
      txn.fee_currency&.symbol,

      blank_if_zero(txn.gain),
      txn.net_value,
      blank_if_zero(txn.fee_value),
      txn.description
    ]
  end

  def blank_if_zero(amount)
    amount.zero? ? nil : amount
  end
end