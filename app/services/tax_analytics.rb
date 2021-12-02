class TaxAnalytics
  attr_accessor :user, :year, :from, :to

  def initialize(user, options)
    @user = user
    @year, @from, @to = options[:year], options[:from], options[:to]
    @from, @to = user.year_start_end_dates(year) unless from && to
  end

  # displayed on tax reports page and in full tax report
  def full_summary
    {
      from: from,
      to: to,
      transactions: transaction_summary,
      capital_gains: capital_gains_summary,
      income: income_summary,
      expenses: expense_summary,
      special: special_withdrawals_summary,
      margin: margin_summary,
      zero_cost_gains_total: investments.extraction_failed.sum(:gain),
      gains_blocked: user.gains_blocked?,
      gains_progress: user.gains_progress(false),
    }
  end

  # displayed on dashboard
  def stats
    q = transactions
    {
      amount_received: q.crypto_deposits.where(label: nil).sum(:net_value),
      amount_sent: q.crypto_withdrawals.where(label: nil).sum(:net_value),
      costs: q.where.not(fee_currency: nil).sum(:fee_value) + expense_transactions.sum(:net_value),
      income: q.deposits.where(label: Transaction::INCOME_LABELS).sum(:net_value),
      gains: investments.sum(:gain),
      txns_in_period: q.count,
      txn_sparkline: generate_txn_sparkline(from, to),
      total_investable_cash: user.total_fiat_worth,
      total_worth: user.total_worth,
      total_txns: user.txns.count,
    }
  end

  def transaction_summary
    q = transactions
    {
      total: q.count,
      deposits: q.crypto_deposits.count,
      withdrawals: q.crypto_withdrawals.count,
      trades: q.where(type: [Transaction::EXCHANGE, Transaction::BUY, Transaction::SELL]).count,
      transfers: q.where(type: Transaction::TRANSFER).count,
      errors: q.where(negative_balances: true).count
    }
  end

  def income_summary
    summary = Hash.new(0)
    q = transactions
    Transaction::INCOME_LABELS.each do |label|
      summary[label] = q.deposits.where(label: label).sum(:net_value)
    end
    summary[:total] = summary.values.sum
    summary.symbolize_keys
  end

  def expense_summary
    summary = Hash.new(0)
    q = transactions
    Transaction::EXPENSE_LABELS.each do |label|
      summary[label] += q.withdrawals.where(label: label).sum(:net_value)
    end
    summary[:total] = summary.values.sum
    summary.symbolize_keys
  end

  def special_withdrawals_summary
    summary = Hash.new(0)
    q = transactions
    (Transaction::SPECIAL_LABELS - [Transaction::IGNORED]).each do |label|
      summary[label] = user.investments.withdrawals.joins(:txn).merge(q.crypto_withdrawals.where(label: label)).sum(:value)
    end
    summary[:total] = summary.values.sum
    summary.symbolize_keys
  end

  def capital_gains_summary(q = investments)
    summary = Hash.new(0)
    summary[:disposals] = q.withdrawals.without_subtype(excluded_subtypes).count
    summary[:profit] = q.withdrawals.without_subtype(excluded_subtypes).where('gain > 0').sum(:gain)
    summary[:loss] = q.withdrawals.without_subtype(excluded_subtypes).where('gain < 0').sum(:gain).abs
    summary[:net] = summary[:profit] - summary[:loss]
    summary[:costs] = q.withdrawals.sum(:value)
    summary[:proceeds] = summary[:costs] + summary[:net]
    summary[:failed] = q.where(subtype: Investment::FAILED).count
    summary
  end

  def capital_gains_by_period_summary
    {
      short_term: capital_gains_summary(investments.where(long_term: false)),
      long_term: capital_gains_summary(investments.where(long_term: true)),
    }
  end

  def margin_summary
    invs = investments
    summary = Hash.new(0)
    summary[:count] = invs.where(subtype: Investment::EXTERNAL).count
    summary[:profit] = invs.where(subtype: Investment::EXTERNAL).where('gain > 0').sum(:gain)
    summary[:loss] = invs.where(subtype: Investment::EXTERNAL).where('gain < 0').sum(:gain).abs
    summary[:net] = summary[:profit] - summary[:loss]
    summary.symbolize_keys
  end

  def asset_summary(base = investments.withdrawals)
    assets = base.without_subtype(excluded_subtypes)
      .group(:currency_id)
      .pluck(Arel.sql('currency_id, sum(amount) as amount, sum(value) as value, sum(CASE WHEN gain > 0 THEN gain ELSE 0 END) as profit, sum(CASE WHEN gain < 0 THEN gain ELSE 0 END) as loss, sum(gain) as net'))

    assets = assets.map do |asset|
      {
        currency_id: asset[0],
        amount: asset[1].abs.round(8),
        costs: asset[2].round(2),
        proceeds: (asset[2] + asset[5]).round(2),
        profit: asset[3].round(2),
        loss: asset[4].abs.round(2),
        net: asset[5].round(2),
      }
    end

    with_currency_symbols assets.sort_by{ |x| [-x[:net].to_d, x[:currency_id].to_i] }
  end

  def asset_profit_summary
    asset_summary(investments.where('gain > 0'))
  end

  def asset_loss_summary
    asset_summary(investments.where('gain < 0'))
  end

  def capital_gains_disposals
    rows = []
    ordered_investments.withdrawals.without_subtype(excluded_subtypes).each_slice(500) do |chunked_ids|
      Investment.where(id: chunked_ids).ordered.each do |investment|
        rows << capital_gains_row(investment)
      end
    end
    with_currency_symbols rows
  end

  def income_transactions
    ordered_transactions.deposits.where(label: Transaction::INCOME_LABELS).includes(:to_currency)
  end

  def expense_transactions
    ordered_transactions.withdrawals.where(label: Transaction::EXPENSE_LABELS).includes(:from_currency)
  end

  def special_transactions
    ordered_transactions.crypto_withdrawals.where(label: (Transaction::SPECIAL_LABELS - [Transaction::IGNORED])).includes(:from_currency)
  end

  def transactions
    date_field = Transaction.arel_table[:date]
    user.txns.where(date_field.gteq(from)).where(date_field.lt(to))
  end

  def investments
    date_field = Investment.arel_table[:date]
    user.investments.where(date_field.gteq(from)).where(date_field.lt(to))
  end

  def ordered_transactions
    transactions.order(date: :asc)
  end

  def ordered_investments
    investments.ordered
  end

  private

  def excluded_subtypes
    exclude = [Investment::WASH_SALE, Investment::AMOUNT_ONLY_FEE, Investment::OWN_TRANSFER]
    exclude << Investment::EXTERNAL unless user.treat_margin_gains_as_capital_gains
    exclude
  end

  def capital_gains_row(investment)
    {
      currency_id: investment.currency_id,
      amount: investment.amount.abs.floor(8),
      acquired_on: investment.from_date, # nil for acb and margin trades
      sold_on: investment.date,
      buying_price: investment.value.round(2),
      selling_price: (investment.value + investment.gain).round(2),
      gain: investment.gain.round(2),
      long_term: investment.long_term,
      notes: investment.notes,
      symbol: nil # added afterwards
    }
  end

  def with_currency_symbols(rows)
    currencies = Currency.where(id: rows.map{ |x| x[:currency_id] }.uniq).inject({}) { |memo, curr| memo.tap{ memo[curr.id] = curr.symbol } }
    rows.each{ |x| x[:symbol] = currencies[x[:currency_id]] }
  end

  def generate_txn_sparkline(from, to)
    from = from.utc.beginning_of_day
    to = (to + 1.day).utc.beginning_of_day
    t = (to.to_i - from.to_i)
    if t > 12.months
      grouping = 'month'
    elsif t > 31.days
      grouping = 'week'
    else
      grouping = 'day'
    end

    # this query ensures we also get data when there are no transactions in a certain period
    result = ActiveRecord::Base.connection.execute("
        SELECT *
        FROM (SELECT day::date FROM generate_series(date_trunc('#{grouping}', timestamp '#{from.to_s}'), date_trunc('#{grouping}', timestamp '#{to.to_s}'), interval  '1 #{grouping}') day) d
        LEFT JOIN (#{transactions.select("date_trunc('#{grouping}', date)::date AS day, count(id) AS num").group('1').to_sql}) t USING (day)
        ORDER BY day
      ")

    result.as_json.map { |x| x['num'] || 0 }
  end
end