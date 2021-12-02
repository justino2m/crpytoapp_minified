class BaseImporter
  include ActiveModel::Validations
  include SyncMetadataAndPagination
  attr_reader :current_wallet, :current_user, :started_at, :options, :adapter
  metadata :balances
  metadata :balance_diff
  metadata :initial_sync_done
  metadata :known_markets

  validate :ensure_required_options_present
  validate :ensure_no_duplicate_symbols_in_wallet

  def initialize(wallet, options)
    @options = options
    @current_wallet = wallet
    @current_user = wallet.user
    @started_at = Time.now
    @adapter = TxnBuilder::Adapter.new(current_user, wallet, true)
  end

  def self.required_options
    []
  end

  # these are optional options that an api may require, you can set the type of the field ex.
  # [start_from: :datetime, import_trades: :boolean]
  # supported types: boolean, string
  def self.other_options
    []
  end

  # these are hardcoded on the frontend
  def self.basic_options
    [:deposit_label, :withdrawal_label, :start_date, :ignore_reported_balances]
  end

  # this is displayed to users. prefix with "good", "bad" and "limit" so frontend
  # can display it correctly. You can also use html.
  def self.notes
    []
  end

  # this acts as both getter and setter. tag must be unique for every importer
  def self.tag(tag = nil)
    @tag ||= tag || name.underscore.sub('_importer', '')
  end

  def self.symbol_alias_tag
    tag
  end

  # optional: returns oauth url if wallet supports it
  def self.oauth_url
  end

  def self.process(wallet, options)
    importer = new(wallet, options)
    if importer.valid?
      importer.process
    else
      raise SyncAuthError, importer.errors.full_messages.join(', ')
    end
  end

  def process
    begin
      import
      adapter.commit! # must commit before updating balance diffs

      # update balances and diffs
      balances = (sync_balances || {})
        .delete_if{ |_, v| v.nil? }
        .transform_keys{ |k| k.is_a?(Currency) ? k : k.to_s.upcase }
        .transform_values{ |v| v.to_d.round(10) }
      update_balance_diff(balances)
      save_reported_balances(balances)

      self.initial_sync_done = true
    ensure
      adapter.commit! # updating balance diffs can also result in new txns
      current_wallet.save
    end
  end

  protected

  def import
    fail 'not implemented'
  end

  # should return hash of balances, the key may also be a currency object
  #   { "BTC" => 2.55, "ETH" => 35 }
  def sync_balances
    fail 'not implemented'
  end

  # importers can override this method to run more in depth queries to fetch all
  # data when balance diffs are found, it should return true if more txns were added
  def fix_balance_diff(diff, balances)
  end

  # this is the max amount of txns we want to import (used by coins)
  def historical_txns_limit
    10_000
  end

  # this is the max pages that the with_pagination method will loop
  def max_pages_per_sync
    50
  end

  protected

  def ensure_required_options_present
    missing = self.class.required_options - options.keys
    errors.add(:base, "missing required fields: #{missing.join(', ')}") if missing.any?
  end

  # ensure user doesnt have multiple accounts with the same symbol - this is usually a bug
  # as there is no reason for a synced wallet to contain duplicate currency symbols
  def ensure_no_duplicate_symbols_in_wallet
    symbols = Currency.unscoped.where(id: current_wallet.accounts.select(:currency_id)).pluck(:symbol, :id)
    symbols.select! { |x| symbols.count { |y| x[0] == y[0] } > 1 }
    if symbols.any?
      # try to delete duplicate accounts with no transactions
      deleted = []
      symbols.map do |sym|
        account = current_wallet.accounts.find_by(currency_id: sym[1])
        unless account.txns.exists?
          account.destroy!
          deleted << sym
        end
      end
      symbols -= deleted

      symbols.select! { |x| symbols.count { |y| x[0] == y[0] } > 1 }
      errors.add(:base, "duplicate accounts detected in #{current_wallet.name}: #{symbols.map(&:join.with(' - ')).sort.join(', ')}") if symbols.any?
    end
  end

  def update_balance_diff(balances)
    # balances can contain currency objects which may have the same symbol, we sum their
    # balances in such cases (the generate_diff method does the same thing)
    balances = balances.dup.each_with_object(Hash.new(0)) do |(coin, bal), obj|
      obj[coin.is_a?(Currency) ? coin.symbol : coin] += bal
    end

    new_diff = generate_balance_diff(balances)
    if new_diff.present? && fix_balance_diff(new_diff, balances)
      adapter.commit!
      new_diff = generate_balance_diff(balances)
    end

    self.balances = balances.delete_if{ |_, v| v.to_d.zero? }
    self.balance_diff = new_diff
  end

  def generate_balance_diff(real_balances)
    # some symbols are named sth else on certain exchanges, we need to convert them back
    adjusted_balances = real_balances.inject({}) do |memo, (symbol, balance)|
      aliased_symbol = adapter.resolve_symbol_alias(self.class.symbol_alias_tag, symbol)&.symbol
      memo.tap { memo[aliased_symbol || symbol] = balance }
    end

    calculated_balances = current_wallet.accounts.includes(:currency).inject(Hash.new(0)) do |memo, account|
      memo.tap { memo[account.currency.symbol] += account.balance }
    end

    diff = (adjusted_balances.keys + calculated_balances.keys).uniq.inject({}) do |memo, symbol|
      memo.tap { memo[symbol] = calculated_balances[symbol].to_d.round(8) - adjusted_balances[symbol].to_d.round(8) }
    end

    diff.delete_if { |_, v| v.zero? }.transform_values!(&:to_s).sort.to_h
  end

  def save_reported_balances(balances)
    # current_wallet.accounts.update_all(reported_balance: nil)
    # return if options[:ignore_reported_balances].present?
    #
    # accounts = current_wallet.accounts.includes(:currency).to_a
    # updated = []
    # conflicts = []
    # balances.each do |coin, balance|
    #   next if balance.zero?
    #   found = accounts.select{ |acc| coin.is_a?(Currency) ? acc.currency == coin : acc.currency.symbol == coin }
    #   if found.count > 1 # importer should return Currency objects to prevent this
    #     conflicts << found
    #   elsif found.empty?
    #     curr = coin.is_a?(Currency) ? coin : Currency.where(symbol: coin).first
    #     # we dont want to show balances for crap tokens unless they have transactions
    #     next if curr.nil? || curr.spam? || curr.rank.nil? || !curr.active? || balance < 0.0001 || curr.rank > 100
    #     updated << current_wallet.accounts.build(user: current_user, currency: curr, balance: 0, reported_balance: balance)
    #   else
    #     account = found.first
    #     account.reported_balance = balance
    #     updated << account
    #   end
    # end
    #
    # no_balances = accounts - updated - conflicts.flatten
    # Account.where(id: no_balances).update_all(reported_balance: 0) if no_balances.any?
    # Account.import(updated, on_duplicate_key_update: [:reported_balance], validate: false) if updated.any?
  end

  def sync_trade(
    base_amount:,
    base_symbol:,
    quote_amount:,
    quote_symbol:,
    fee_amount: nil,
    fee_currency: nil,
    is_buy:,
    date:,
    trade_identifier:,
    order_identifier:,
    external_data: nil,
    description: nil,
    net_worth_amount: nil,
    net_worth_currency: nil,
    margin: false,
    allow_txhash_conflicts: false,
    prevent_same_run_conflicts: false
  )
    return if skip_trade?(TxnBuilder::Helper.normalize_date(date))

    base_amount = TxnBuilder::Helper.normalize_amount(base_amount, true)
    quote_amount = TxnBuilder::Helper.normalize_amount(quote_amount, true)
    sync_txn(
      from_amount: (is_buy ? quote_amount : base_amount),
      from_currency: (is_buy ? quote_symbol : base_symbol),
      to_amount: (is_buy ? base_amount : quote_amount),
      to_currency: (is_buy ? base_symbol : quote_symbol),
      txhash: order_identifier,
      external_id: trade_identifier,
      date: date,
      description: description,
      net_worth_amount: net_worth_amount,
      net_worth_currency: net_worth_currency,
      fee_amount: fee_amount,
      fee_currency: fee_currency,
      external_data: external_data,
      margin: margin,
      allow_txhash_conflicts: allow_txhash_conflicts,
      prevent_same_run_conflicts: prevent_same_run_conflicts,
      )
  end

  def sync_send(
    amount:,
    currency:,
    date:,
    label: nil,
    txhash: nil,
    txsrc: nil,
    txdest: nil,
    external_id: nil,
    external_data: nil,
    description: nil,
    net_worth_amount: nil,
    net_worth_currency: nil,
    utxo: false,
    group_name: nil,
    allow_txhash_conflicts: false,
    prevent_same_run_conflicts: false
  )
    sync_txn(
      from_amount: amount,
      from_currency: currency,
      label: (label || options[:withdrawal_label]),
      date: date,
      description: description,
      net_worth_amount: net_worth_amount,
      net_worth_currency: net_worth_currency,
      txhash: txhash,
      txsrc: txsrc,
      txdest: txdest,
      external_id: external_id,
      external_data: external_data,
      utxo: utxo,
      group_name: group_name,
      allow_txhash_conflicts: allow_txhash_conflicts,
      prevent_same_run_conflicts: prevent_same_run_conflicts,
      )
  end

  def sync_receive(
    amount:,
    currency:,
    date:,
    label: nil,
    txhash: nil,
    txsrc: nil,
    txdest: nil,
    external_id: nil,
    external_data: nil,
    description: nil,
    net_worth_amount: nil,
    net_worth_currency: nil,
    utxo: false,
    group_name: nil,
    allow_txhash_conflicts: false,
    prevent_same_run_conflicts: false
  )
    sync_txn(
      to_amount: amount,
      to_currency: currency,
      label: (label || options[:deposit_label]),
      date: date,
      description: description,
      net_worth_amount: net_worth_amount,
      net_worth_currency: net_worth_currency,
      txhash: txhash,
      txsrc: txsrc,
      txdest: txdest,
      external_id: external_id,
      external_data: external_data,
      utxo: utxo,
      group_name: group_name,
      allow_txhash_conflicts: allow_txhash_conflicts,
      prevent_same_run_conflicts: prevent_same_run_conflicts,
      )
  end

  def sync_amount(txn)
    amount = txn.fetch(:amount).to_d
    if amount > 0
      sync_receive(txn)
    elsif amount < 0
      sync_send(txn)
    end
  end

  def sync_txn(params)
    return if skip_txn?(TxnBuilder::Helper.normalize_date(params[:date]))

    params.merge!(
      importer_tag: self.class.symbol_alias_tag,
      synced: true
    )

    klass = nil
    if params[:from_currency] && params[:to_currency]
      klass = TxnBuilder::Trade
    elsif params[:from_currency]
      klass = TxnBuilder::Withdrawal
    elsif params[:to_currency]
      klass = TxnBuilder::Deposit
    else
      fail("tried to import bad transaction")
    end

    klass.create!(current_user, current_wallet, params, adapter)
  end

  def skip_txn?(date)
    options[:start_date].present? && (@start_date ||= Time.parse(options[:start_date])) > date
  end

  def skip_trade?(date)
    options[:trade_start_date].present? && (@trade_start_date ||= Time.parse(options[:trade_start_date])) > date
  end

  def wallet_created_after?(date)
    current_wallet.created_at > date.to_datetime
  end

  # use this when converting amounts to decimals, this avoids memory leak if decimals
  # are exceptionally high, an eth token had 100000000 which caused pg to go oom
  #   decimalize(1000_0000, 8) = 1
  def decimalize(amount, decimals)
    # note: dont use Helper.normalize since it returns abs()
    (amount.to_d / 10**decimals.to_i.clamp(0, 1000)).round(10)
  end

  def initial_sync?
    !initial_sync_done?
  end

  # helper method for saving known markets, useful for exchanges that require looping
  # over all markets to find trades. save the known ones in each sync and check trades
  # on subsequent syncs
  def add_known_market(market)
    return if market.nil? || known_markets&.include?(market)
    self.known_markets ||= []
    known_markets.append(market)
  end

  # error can be an exception or a string
  # this method must return the logged error message
  def log_error(error, data = {})
    @logged_errors ||= []
    message = error.try(:message) || error
    unless @logged_errors.include?(message)
      if error.is_a?(Exception)
        Rollbar.error(error, data.merge(current_wallet: current_wallet.id))
      else
        Rollbar.warning(error, data.merge(current_wallet: current_wallet.id))
      end
      @logged_errors << message
    end
    message
  end

  def fail(message, data = nil)
    Rollbar.debug(message, data) if data
    raise SyncError, message
  end

  def fail_perm(message, data = nil)
    Rollbar.debug(message, data) if data
    raise SyncAuthError, message
  end
end
