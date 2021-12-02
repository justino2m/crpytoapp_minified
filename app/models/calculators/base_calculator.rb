class BaseCalculator
  attr_reader :current_user, :pending_investments, :pending_transactions

  def initialize(user)
    @current_user = user
    @pending_investments = []
    @pending_transactions = []
  end

  def process
    # this is just a safety measure, so we regen investments for txns that dont have any investments
    # even if their gain is not nulled for ex. if server crashes before the txn is updated
    current_user.txns.without_investments.where.not(gain: [nil, 0]).update_all(gain: nil)

    # since transfers can change the date of a txn, we have to ensure their investments are explicitly nulled
    # as delete_investments_after_new_txns wont be able to find them because their date is not same as
    # the date of the txn
    current_user.investments.where(transaction_id: current_user.txns.pending_gains.select(:id)).soft_delete!

    delete_investments_after_new_txns if current_user.investments.exists?

    # delete investments for txns that were modified/deleted
    while current_user.investments.pending_deletion.exists?
      yield(false) if block_given?
      delete_investments(current_user.investments.pending_deletion)
    end

    # transfers are having this issue, not sure whats causing it - maybe a transfer is being created
    # in a wallet or csv import job while gains are being updated. The transfer would have to be created
    # after the call to delete_invs_after_new_txns and before the fetch_txns, so we are adding this check
    # in between
    # Update: this was being caused because of transfer dates getting updated
    if current_user.investments.where(transaction_id: current_user.txns.pending_gains.select(:id)).exists?
      raise "txn with pending gains and investments found for user #{current_user.id}"
    end

    fetch_transactions do |txn|
      yield(false) if block_given?
      raise QuitWorkerSignal, 'transaction deleted' unless txn # means it was deleted while we were looping
      create_investment(txn)

      if pending_transactions.count > 500 || pending_investments.count > 500
        yield(true) if block_given? # force check for changes before commiting
        commit_pending_investments
        commit_pending_transactions
      end
    end

    yield(true) if block_given?
    commit_pending_investments
    commit_pending_transactions
  end

  protected

  def fetch_transactions
    BatchLoad.call(current_user.txns.pending_gains.ordered, 200, &Proc.new)
  end

  # average cost methods require some additional logic
  def average_cost_method?
    false
  end

  # whether to realize gains on txns tagged as gifts, lost etc
  def gains_on_special_labels?
    false
  end

  # override and set to true if the calculator uses wash-sales, this will cause
  # additional queries to be ran when a deposit is created to check if it is a
  # wash sale or not as per the defined logic
  def has_wash_sales?
    false
  end

  # override and set to true if the method also defers losses in the previous X
  # days when adding a withdrawal but does not use a separate pool for the previous
  # days for ex. acb_canada
  def has_reverse_wash_sales?
    false
  end

  # this method is an iterator, it must call the supplied block and not just return an array!
  # the parameter passeed to it is never persisteed, it just contains everything this method
  # needs to work
  def fetch_deposits(dummy_withdrawal)
    raise 'not implemented'
  end

  # this is just a helper method for derived classes, it is used in fetch_deposits
  def base_deposits_query(withdrawal)
    # note: ordering is done in derived classes like Fifo, Lifo etc
    current_user.investments.extractable
      .where(cost_basis_pool(withdrawal))
      .earlier_than(withdrawal)
  end

  # this method is an iterator, it must call the supplied block and not just return an array!
  def fetch_wash_sales(deposit)
    raise 'not implemented'
  end

  def base_wash_sales_query(deposit)
    # add a date limit
    current_user.investments.withdrawals
      .where('gain < 0')
      .where(cost_basis_pool(deposit))
      .earlier_than(deposit)
      .ordered
  end

  protected

  def delete_investments_after_new_txns
    key = cost_basis_pool_key
    q = current_user.txns.pending_gains
    ids = (q.distinct.pluck("from_#{key}") + q.distinct.pluck("to_#{key}") + q.distinct.pluck("fee_#{key}")).compact.uniq
    ids.each do |id|
      if key == :account_id
        date = q.order(date: :asc).by_account_id(id).limit(1).pluck(:date).first
      else
        date = q.order(date: :asc).by_currency_id(id).limit(1).pluck(:date).first
      end

      delete_investments_in_pool(key, id, date) if date
    end
  end

  def delete_investments_in_pool(pool_key, pool_id, date)
    # here we use the transaction_id instead of simply soft deleting the investments for the pool
    # so that even trades/transfers that are in a different pool get deleted
    txns = current_user.investments.where(pool_key => pool_id).where('date >= ?', date).select(:transaction_id)

    # note: this can cause the deposit investments for sells/exchanges to be soft deleted while
    # withdrawals from those deposits would not be soft deleted yet. however the recurring calls
    # to delete_investments will take care of that
    current_user.investments.where(transaction_id: txns).soft_delete!

    Transaction.where(id: txns).where.not(gain: nil).update_all(gain: nil)
  end

  def dependent_investment_ids(investments)
    investments.select(:from_id)
  end

  # we want to delete all investments after the oldest touched investment,
  # for ex. if one of the withdrawals being deleted extracted from a deposit thats not
  # being deleted then we want to delete that deposit and subsequent withdrawals too, ex:
  #   D | D | [ W | W | D | W ]     # the ones in square brackets are the investments being deleted now
  #       \-----|---|               <- the second deposit in this case
  # note that for wash sale enabled calculators, a deposit might also depend on a withdrawal
  def delete_investments(investments)
    oldest_deleted_inv_per_pool = current_user.investments
      .where('id IN (:id) OR id IN (:dependent_ids)', id: investments.select(:id), dependent_ids: dependent_investment_ids(investments))
      .group(cost_basis_pool_key)
      .pluck(Arel.sql(cost_basis_pool_key.to_s), Arel.sql('min(date)'))

    # the delete_investments_in_pool method can result in a deposit being soft deleted while
    # withdrawals from it will not be (for exchanges/sells) so we must ensure only invs
    # without references are deleted here (the remaining ones will be deleted on subsequent
    # calls to this method)
    invs_with_refs = current_user.investments.where(from_id: investments.select(:id)).where.not(id: investments.select(:id))
    investments.where.not(id: invs_with_refs.select(:from_id)).delete_all

    # delete all investments after the oldest dirty deposit (per pool) so they get recreated on subsequent calls
    oldest_deleted_inv_per_pool.each do |(pool_id, date)|
      delete_investments_in_pool(cost_basis_pool_key, pool_id, date)
    end
  end

  def create_investment(txn)
    # this is used to avoid making db query when accessing txn.investments since we know there
    # are no investments in db atm
    txn.pending_investments = []

    if txn.ignored? ||
      (txn.transfer? && !current_user.account_based_cost_basis? && !txn.fee?) || # no investments needed for transfers without fees
      ((txn.trade? || txn.transfer?) && fiat?(txn.from_currency_id) && fiat?(txn.to_currency_id)) || # eur to usd
      ((txn.fiat_deposit? || txn.fiat_withdrawal?) && txn.label != Transaction::REALIZED_GAIN)
      return update_transaction_gains(txn, [])
    end

    if txn.label == Transaction::REALIZED_GAIN
      if txn.from_currency_id
        inv = create_withdrawal(txn, txn.from_currency_id, txn.from_account_id, 0, Investment::EXTERNAL)
        inv.gain = -txn.net_value if inv
      else
        # note: need to call create_deposit even though it should be a withdrawal so that share_pool can work
        inv = create_deposit(txn, txn.to_currency_id, txn.to_account_id, 0, 0, Investment::EXTERNAL)
        if inv
          inv.deposit = false
          inv.gain = txn.net_value
        end
      end

      # for crypto gains we have to add a deposit investment and for withdrawals we have to realize gains
      # for the investment. note that for withdrawals this will have the same affect as losing the cost-basis
      return update_transaction_gains(txn, txn.pending_investments) unless txn.crypto_deposit? || txn.crypto_withdrawal?
    end

    # fiat fees will be added to net_value for deposits and subtracted for withdrawals
    fiat_fee_value = (txn.fee? && fiat?(txn.fee_currency_id)) ? txn.fee_value : 0

    if txn.crypto_deposit? || txn.buy?
      deposit = create_deposit(txn, txn.to_currency_id, txn.to_account_id, txn.to_amount, txn.net_value + fiat_fee_value)
    elsif txn.exchange? || (txn.transfer? && current_user.account_based_cost_basis?)
      # a nil net value will ensure that gains are 0 so we can put the extracted value into the new deposit
      # effectively transferring the value from one crypto to another
      # transfers should never realize gains, they should only result in new withdrawals and deposits so
      # that fifo/lifo methods use the correct deposits, same goes for crypto to crypto trades when not realizing
      # we tag them with OWN_TRANSFER so we cant skip them in tax reports
      net_value = (!txn.transfer? && current_user.realize_gains_on_exchange?) ? txn.net_value : nil
      tag = net_value.present? ? nil : Investment::OWN_TRANSFER
      withdrawals = create_and_extract_withdrawal(txn, txn.from_currency_id, txn.from_account_id, txn.from_amount, net_value, tag)

      if txn.exchange? || !current_user.country.has_long_term?
        deposit = create_deposit(txn, txn.to_currency_id, txn.to_account_id, txn.to_amount, (net_value || withdrawals.sum(&:value)) + fiat_fee_value, tag)
      else
        # need to carry over holding periods for transfers so creating multiple deposits
        withdrawals.map do |with|
          dep = create_deposit(txn, txn.to_currency_id, txn.to_account_id, with.amount.abs, with.value, tag)
          dep.from_date = with.from_date
        end
      end
    elsif txn.crypto_withdrawal? || txn.sell?
      # crypto withdrawals with labels (gift/lost) should not realize any gains
      net_value =
        (txn.sell? || gains_on_special_labels? || Transaction::SPECIAL_LABELS.none? { |x| x == txn.label }) ?
          [txn.net_value - fiat_fee_value, 0].max :
          nil

      create_and_extract_withdrawal(txn, txn.from_currency_id, txn.from_account_id, txn.from_amount, net_value)
    end

    if txn.fee? && !fiat?(txn.fee_currency_id)
      if txn.buy? || txn.exchange?
        fee_value = current_user.realize_gains_on_exchange? ? txn.fee_value : nil
        tag = fee_value.present? ? Investment::FEE : Investment::OWN_TRANSFER_FEE
        withdrawals = create_and_extract_withdrawal(txn, txn.fee_currency_id, txn.fee_account_id, txn.fee_amount, fee_value, tag)
        apply_fee_value_to_deposit(deposit, fee_value || withdrawals.sum(&:value)) if deposit
      elsif txn.sell? || (txn.transfer? && current_user.realize_transfer_fees?)
        # here transfer fees are treated as a withdrawal instead of a deductible cost so they are not added onto the deposited value
        create_and_extract_withdrawal(txn, txn.fee_currency_id, txn.fee_account_id, txn.fee_amount, txn.fee_value, Investment::FEE)
      elsif txn.transfer?
        # this will reduce amount of invested coins but keep value of investments the same
        # note: we use this even if account based cost basis is enabled due to simplicity and backwards compatibility
        create_and_extract_withdrawal(txn, txn.fee_currency_id, txn.fee_account_id, txn.fee_amount, nil, Investment::AMOUNT_ONLY_FEE)
      end
    end

    # we do this at the end so that crypto fees are included in it
    apply_wash_sale_rule(txn, deposit) if has_wash_sales? && deposit && !txn.transfer?
    apply_reverse_wash_sale_rule(txn) if has_reverse_wash_sales? && !txn.transfer?
    update_transaction_gains(txn, txn.pending_investments)
  end

  def update_transaction_gains(txn, investments = nil)
    investments ||= txn.investments

    # when txns are imported correctly, the gain can be come ridiculously high so
    # we cap it to avoud PG::NumericValueOutOfRange
    txn.gain = investments.sum(&:gain).clamp(-10**9, 10**9)
    txn.from_cost_basis = investments.select(&:withdrawal?).sum(&:value).clamp(0, 10**9)
    txn.to_cost_basis = investments.reject(&:withdrawal?).sum(&:value).clamp(0, 10**9)

    missing_cost = investments.select(&:failed?).sum(&:gain) # gain on missing txns is always positive
    txn.missing_cost_basis = missing_cost > 0 ? missing_cost.clamp(0, 10**9) : nil

    pending_transactions.reject! { |x| x.id == txn.id } # wash sales can result in multiple calls here
    pending_transactions << txn
  end

  def apply_fee_value_to_deposit(deposit, value)
    # if the fee is extracted from this deposit then we need to update the deposit here
    found = pending_investments.find { |inv| inv == deposit }
    if found
      found.value += value
    else
      deposit.value += value
      pending_investments << deposit
    end
  end

  def create_deposit(txn, currency_id, account_id, amount, value, subtype = nil, add = true)
    investment = txn.investments.build(
      user: current_user,
      deposit: true,
      transaction_id: txn.id,
      currency_id: currency_id,
      account_id: account_id,
      amount: amount,
      value: value,
      gain: 0,
      subtype: subtype,
      date: txn.date,
      )
    if add
      txn.pending_investments << investment
      pending_investments << investment
    end
    investment
  end

  def create_withdrawal(txn, currency_id, account_id, amount, subtype = nil, add = true)
    investment = txn.investments.build(
      user: current_user,
      deposit: false,
      transaction_id: txn.id,
      currency_id: currency_id,
      account_id: account_id,
      amount: -amount.abs,
      value: 0, # will be set by extractor
      gain: 0,  # will be set by extractor
      subtype: subtype,
      date: txn.date,
      )
    if add
      txn.pending_investments << investment
      pending_investments << investment
    end
    investment
  end

  def create_and_extract_withdrawal(txn, currency_id, account_id, amount, value, subtype = nil)
    commit_pending_investments

    # this usually returns withdrawals but can also return a failed deposit for average_cost methods
    investments = calculate_gains_and_withdrawals(txn, currency_id, account_id, amount, value, subtype)

    # update the extracted amount for the deposits that we just extracted from
    deposits = investments.map(&:from).compact
    deposits.each do |dep|
      sel = investments.select { |x| x.from_id == dep.id }
      # these can be nil if no rows
      extracted_amount, extracted_value = dep.to.pluck(Arel.sql('sum(amount)'), Arel.sql('sum(value)')).first
      dep.extracted_amount = extracted_amount.to_d.abs + sel.sum(&:amount).abs
      dep.extracted_value = extracted_value.to_d + sel.sum(&:value).abs
    end

    investments.each { |x| txn.pending_investments << x }
    pending_investments.push(*investments)
    pending_investments.push(*deposits.select(&:changed?))
    investments.select(&:withdrawal?)
  end

  def calculate_gains_and_withdrawals(txn, currency_id, account_id, amount, value, subtype = nil)
    # we create a dummy struct as its easier to pass data around in it
    dummy_inv = OpenStruct.new(txn: txn, currency_id: currency_id, account_id: account_id, amount: -amount, value: value, date: txn.date, subtype: subtype)

    investments = []
    generate_extractions(txn, dummy_inv).each do |x|
      withdrawal = create_withdrawal(txn, currency_id, account_id, x.amount, subtype, false)
      withdrawal.value = x.value unless subtype == Investment::AMOUNT_ONLY_FEE
      withdrawal.from = x.from
      # if a deposit was transferred from another wallet then we want to use the original from_date
      withdrawal.from_date = x.from.try(:from_date) || x.from.try(:date)
      withdrawal.long_term = current_user.country.long_term?(withdrawal.from_date, withdrawal.date)
      withdrawal.pool_name = x.pool_name
      withdrawal.metadata = x.metadata
      investments << withdrawal
    end

    amount_left = amount - investments.sum(&:amount).abs
    if amount_left > 0.0000_001
      # for acb we have to create a 0 value deposit otherwise subsequent deposit/withdrawals would be incorrect
      # due to the negative withdrawal. we may want to do this later on for fifo etc as well but it would require
      # saving the deposit first which is an extra call to db - not sure about the impact of this on other methods
      # also need to update the end_of_year_balances method to not ignore failed ones since they would be in balance
      investments << create_deposit(txn, currency_id, account_id, amount_left, 0, Investment::FAILED, false) if average_cost_method?
      failure = create_withdrawal(txn, currency_id, account_id, amount_left, Investment::FAILED, false)
      # shared_pool can return nil in create_withdrawal
      if failure
        failure.from_date = txn.date
        investments << failure
      end
    end

    investments.compact!

    investments.select(&:withdrawal?).each do |withdrawal|
      max_value = (value / amount) * withdrawal.amount.abs # proportionate to extracted amount
      withdrawal.gain = max_value - withdrawal.value
    end if value

    investments
  end

  def generate_extractions(txn, dummy_inv)
    extractions = []
    total_amount = dummy_inv.amount.abs
    amount_left = total_amount
    return [] if amount_left <= 0

    catch :done do
      fetch_deposits(dummy_inv) do |deposit, pool_name = nil|
        x = extract_value_from(deposit, amount_left, pool_name)
        extractions << x if x && (x.amount.abs > 0 || x.value > 0)
        amount_left = total_amount - extractions.sum(&:amount).abs
        throw :done if amount_left <= 0
      end
    end

    extractions
  end

  def commit_pending_investments
    return if pending_investments.empty?
    Investment.import(
      pending_investments,
      on_duplicate_key_update: [:value, :gain, :extracted_amount, :extracted_value],
      validate: false
    )
    pending_investments.clear
  end

  def commit_pending_transactions
    return if pending_transactions.empty?
    Transaction.import(
      pending_transactions,
      on_duplicate_key_update: [:from_cost_basis, :to_cost_basis, :gain, :missing_cost_basis],
      validate: false
    )
    pending_transactions.clear
  end

  def extract_value_from(from, total_amount, pool_name)
    extractable_value = from.value - from.extracted_value
    extractable_amount = from.amount.abs - from.extracted_amount
    if extractable_amount <= 0
      # this allows us to handle transfer fees that reduce amount but not value
      build_extraction(from, 0, extractable_value, pool_name) if extractable_value > 0
    else
      amount = extractable_amount > total_amount ? total_amount : extractable_amount
      if amount == extractable_amount
        value = extractable_value
      else
        value = amount * (from.value / from.amount.abs)
      end
      build_extraction(from, amount, value, pool_name)
    end
  end

  def apply_reverse_wash_sale_rule(txn)
    raise "override this"
  end

  def apply_wash_sale_rule(txn, deposit)
    commit_pending_investments

    extractions = generate_wash_sale_extractions(deposit).compact
    return if extractions.empty?
    # we add value to the deposit itself instead of creating additional deposits so that fifo/lifo and
    # other methods that rely on the amounts can work correctly
    deposit.value += extractions.sum(&:value).abs # since only losses are treated as wash sales, value will always be negative
    pending_investments.push(deposit)

    # update the extracted amount for the withdrawals that we just extracted from
    extractions.each do |x|
      x.from.gain -= x.value
      x.from.extracted_amount += x.amount
      pending_investments.push(x.from)

      # need to create a relation so the deposit is deleted when withdrawal is
      with = create_deposit(txn, deposit.currency_id, deposit.account_id, 0, 0, Investment::WASH_SALE)
      with.from = x.from
    end

    # need to know how much has already been extracted from a deposit when we are using reverse wash sales
    # note: this only works for average cost based methods as the extracted_amount is used for regular
    # extractions in fifo etc
    if has_reverse_wash_sales? && average_cost_method?
      deposit.extracted_amount += extractions.sum(&:amount).abs
    end

    # update the gains on the txns
    commit_pending_investments
    from = extractions.map(&:from).reject { |x| x.transaction_id == txn.id }
    ActiveRecord::Associations::Preloader.new.preload(from, :txn)
    from.map(&:txn).uniq.map(&method(:update_transaction_gains))
  end

  def generate_wash_sale_extractions(deposit)
    extractions = []
    total_amount = deposit.amount.abs
    amount_left = total_amount

    catch :done do
      fetch_wash_sales(deposit) do |withdrawal|
        extraction = extract_wash_sale_gain_from(withdrawal, amount_left)
        extractions << extraction if extraction
        amount_left = total_amount - extractions.sum(&:amount)
        throw :done if amount_left <= 0
      end
    end

    extractions
  end

  def extract_wash_sale_gain_from(from, total_amount)
    possible_amount = from.amount.abs - from.extracted_amount
    return if possible_amount <= 0
    amount = possible_amount > total_amount ? total_amount : possible_amount
    if amount == possible_amount
      value = from.gain
    else
      value = amount * (from.gain / possible_amount) # note: gain is already adjusted by prior extractions
    end
    build_extraction(from, amount, value)
  end

  def fiat?(currency_id)
    @fiats ||= Currency.fiat.pluck(:id)
    @fiats.include?(currency_id)
  end

  def cost_basis_pool_key
    current_user.account_based_cost_basis? ? :account_id : :currency_id
  end

  def cost_basis_pool(investment)
    { cost_basis_pool_key => investment.send(cost_basis_pool_key) }
  end

  def build_extraction(from, amount, value, pool_name = nil, metadata = nil)
    OpenStruct.new(
      from: from,
      amount: amount,
      value: value,
      pool_name: pool_name,
      metadata: metadata,
      )
  end
end
