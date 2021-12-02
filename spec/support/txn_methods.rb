module TxnMethods
  def deposit(date, amount, worth_and_currency = nil, options = {})
    w = options[:wallet] || wallet
    amount, currency = separate_amount amount
    net_worth_amount, net_worth_currency = separate_amount(worth_and_currency) if worth_and_currency
    TxnBuilder::Deposit.create!(user, w, options.except(:wallet).merge(date: date, to_amount: amount, to_currency: currency, net_worth_amount: net_worth_amount, net_worth_currency: net_worth_currency))
  end

  def withdraw(date, amount, worth_and_currency = nil, options = {})
    w = options[:wallet] || wallet
    amount, currency = separate_amount amount
    net_worth_amount, net_worth_currency = separate_amount(worth_and_currency) if worth_and_currency
    TxnBuilder::Withdrawal.create!(user, w, options.except(:wallet).merge(date: date, from_amount: amount, from_currency: currency, net_worth_amount: net_worth_amount, net_worth_currency: net_worth_currency))
  end

  def trade(date, from_amount, to_amount, worth_and_currency = nil, options = { fee: nil, fee_worth: nil })
    w = options[:wallet] || wallet
    from_amount, from_currency = separate_amount from_amount
    to_amount, to_currency = separate_amount to_amount
    net_worth_amount, net_worth_currency = separate_amount(worth_and_currency) if worth_and_currency
    fee_amount, fee_currency = separate_amount(options[:fee]) if options[:fee]
    fee_worth_amount, fee_worth_currency = separate_amount(options[:fee_worth]) if options[:fee_worth]
    TxnBuilder::Trade.create!(user, w, options.except(:wallet).merge(date: date, from_amount: from_amount, from_currency: from_currency, to_amount: to_amount, to_currency: to_currency, fee_amount: fee_amount, fee_currency: fee_currency, net_worth_amount: net_worth_amount, net_worth_currency: net_worth_currency, fee_worth_amount: fee_worth_amount, fee_worth_currency: fee_worth_currency), options.delete(:adapter))
  end

  def transfer(date, amount, to_wallet, options = { to_amount: nil })
    w = options[:wallet] || wallet
    amount, currency = separate_amount amount
    to_amount, to_currency = separate_amount(options[:to_amount]) if options[:to_amount]
    to_amount ||= amount

    fee_worth_amount, fee_worth_currency = separate_amount(options[:fee_worth]) if options[:fee_worth]
    TxnBuilder::Transfer.create!(user, w, options.except(:wallet).merge(date: date, from_amount: amount, from_currency: currency, to_amount: to_amount, to_currency: currency, to_wallet: to_wallet, fee_worth_amount: fee_worth_amount, fee_worth_currency: fee_worth_currency))
  end

  def separate_amount(amount)
    amount, currency = amount.split(' ')
    [amount, Currency.find_by!(symbol: currency)]
  end

  def generate_wallet_snapshot(wallet)
    fetcher = ->(q, type) do
      q = q.order(date: :asc, txhash: :asc, from_amount: :asc, to_amount: :asc, id: :asc)
      total = q.count
      {
        type: type,
        count: total,
        first: prettify_txn(q.first),
        last: (total > 1 && prettify_txn(q.last))
      } if total > 0
    end

    types = Transaction::TYPES.sort.map do |type|
      fetcher.call(wallet.txns.where(type: type), type)
    end.compact

    withdrawals = Transaction::CRYPTO_WITHDRAWAL_LABELS.sort.map do |label|
      fetcher.call(wallet.txns.withdrawals.where(label: label), label)
    end.compact

    deposits = Transaction::CRYPTO_DEPOSIT_LABELS.sort.map do |label|
      fetcher.call(wallet.txns.deposits.where(label: label), label)
    end.compact

    margin_trades = fetcher.call(wallet.txns.where(margin: true), 'margin trades')

    fmt = {
      name: wallet.name,
      txn_count: wallet.txns.count,
      entry_count: wallet.entries.count,
      balances: wallet_balances(wallet),
      balance_diff: wallet.balance_diff,
      txns: types,
      labeled_txns: [withdrawals + deposits],
      txn_with_fee: fetcher.call(wallet.txns.where.not(fee_currency: nil), 'with fee'),
      txn_with_net_worth: fetcher.call(wallet.txns.where.not(net_worth_currency_id: nil), 'with metadata'),
      txn_with_desc: fetcher.call(wallet.txns.where.not(description: nil), 'with desc'),
    }

    fmt.merge!(margin_trades: margin_trades) if margin_trades

    fmt
  end

  def reject_untouched_airdrops(wallet)
    diffs = wallet.balance_diff.dup
    # coins where we dont have any transactions
    airdrops = diffs.map do |k, v|
      k unless wallet.accounts.where(currency: Currency.find_by(symbol: k)).exists?
    end
    diffs.reject { |k, v| airdrops.include?(k) }
  end

  def prettify_txn(txn)
    from = "#{txn.from_amount.to_s} #{txn.from_currency.symbol}" if txn.from_currency
    to = "#{txn.to_amount.to_s} #{txn.to_currency.symbol}" if txn.to_currency
    if from && to
      result = from + ' -> ' + to
    elsif from
      result = "Withdraw " + from
    else
      result = "Deposit " + to
    end

    extra_info = []
    extra_info << "fee: #{txn.fee_amount.to_s} #{txn.fee_currency.symbol}" if txn.fee_currency
    extra_info << "net worth: #{txn.net_worth_amount.to_s} #{txn.net_worth_currency.symbol}" if txn.net_worth_currency
    extra_info << "fee worth: #{txn.fee_worth_amount.to_s} #{txn.fee_worth_currency.symbol}" if txn.fee_worth_currency
    extra_info << "label: #{txn.label}" if txn.label
    extra_info << "desc: #{txn.description.to_s}" if txn.description.present?
    extra_info << "txhash: #{txn.txhash.to_s}" if txn.txhash.present?
    extra_info << "txsrc: #{txn.txsrc.to_s}" if txn.txsrc.present?
    extra_info << "txdest: #{txn.txdest.to_s}" if txn.txdest.present?
    extra_info << "importer_tag: #{txn.importer_tag.to_s}" if txn.importer_tag.present?
    extra_info << "net_value: #{txn.net_value.to_s}" unless txn.net_value.zero?
    extra_info << "fee_value: #{txn.fee_value.to_s}" unless txn.fee_value.zero?
    extra_info << "margin trade!" if txn.margin?

    txn.date.to_s + " | " + result + (extra_info.any? ? " (" + extra_info.join(', ') + ")" : "")
  end

  def wallet_balances(wallet)
    calculated_balances = wallet.accounts.includes(:currency).inject(Hash.new(0)) do |memo, account|
      memo.tap { memo[account.currency.symbol] += account.balance }
    end

    calculated_balances
      .transform_values! { |val| val.to_d.round(8) }
      .delete_if { |k, v| v.zero? }
      .transform_values!(&:to_s)
      .sort
      .to_h
  end

  def negative_balance_entries(wallet)
    bad_entries = []
    wallet.accounts.each do |account|
      account.entries.order(date: :asc).each do |entry|
        bal = account.entries.where('date <= ?', entry.date).sum(:amount)
        if bal < 0
          bad_entries << { entry_id: entry.id, symbol: account.currency.symbol, date: entry.date, amount: entry.amount.to_s, balance: bal.to_s }
        end
      end
    end
    bad_entries
  end

  def fetch_account(wallet, symbol)
    wallet.accounts.where(currency_id: Currency.where(symbol: symbol).select(:id)).first
  end

  def print_entries(wallet, symbol)
    EntryBalanceUpdater.call(wallet.user)
    fetch_account(wallet, symbol).entries.ordered.map do |entry|
      append = yield(entry) if block_given?
      "#{entry.date.to_s} #{entry.amount.to_s} #{symbol} (bal: #{entry.balance}) #{entry.txhash}" + (append || '')
    end
  end

  def import_csv(file_name)
    spreadsheet = Roo::Spreadsheet.open(file_fixture(file_name), extension: 'csv')

    CsvImport.create!(
      user: user,
      wallet: wallet,
      file: Rack::Test::UploadedFile.new(file_fixture(file_name)),
      initial_rows: spreadsheet.each.take(20)
    )
  end
end

RSpec.configure do |config|
  config.include TxnMethods
  config.extend TxnMethods
end
