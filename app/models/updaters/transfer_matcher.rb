module TransferMatcher
  extend self
  TYPES = [Transaction::FIAT_DEPOSIT, Transaction::FIAT_WITHDRAWAL, Transaction::CRYPTO_DEPOSIT, Transaction::CRYPTO_WITHDRAWAL].freeze

  # ignore txhash when merging txns from these exchanges.
  # A transaction between 2 wallets can have 2 different txhashes:
  #     source -> temp -> dest
  # so source -> temp is one txhash and temp->dest is another
  # Most exchanges will use the txhash for the initial part of the txn which allows us to match
  # easily but some exchanges use the latter txhash in which case we have to ignore it
  BAD_TXHASH_TAGS = [Tag::BITTREX, Tag::BITMEX].freeze

  # these should only match with other txns with the same hash
  SPECIAL_TXHASHES = %w[gdax_to_coinbase coinbase_to_gdax deribit_subaccount_transfer coinjar_exchange_transfer]

  # this is used to avoid matches between ex. 50 BTC -> 45 BTC as its unlikely a 5 BTC fee was paid
  # these are slightly rich to avoid having to adjust too often
  MAX_TXN_FEES = {
    BTC: 0.1,
    ETH: 0.5,
    XRP: 50,
    BCH: 0.9,
    LTC: 0.9,
    BSV: 0.9,
    EOS: 10,
    BNB: 10,
    XTZ: 20,
  }

  def call(user, all = false)
    q = all ? user.txns : user.txns.pending_gains
    q.not_ignored.not_deleted.where(type: TYPES).where(label: nil).find_each do |txn|
      match = find_potential_match_for_txn(user, txn)
      txn.merge_txn!(match, true) if match
      yield if block_given?
    rescue ActiveRecord::InvalidForeignKey => e
      # we can get this error if we match a deposit/withdrawal with another one that is also part of this loop
      # ActiveRecord::InvalidForeignKey: PG::ForeignKeyViolation: ERROR:  insert or update on table "entries" violates foreign key constraint "fk_rails_8708d81f97"
      # DETAIL:  Key (transaction_id)=(1873094) is not present in table "transactions".
    end
  end

  def find_potential_match_for_txn(user, txn)
    # note: we want to match fiat transfers from coinbase to coinbase pro
    if txn.deposit?
      find_txn(
        user,
        date: txn.date,
        amount: -txn.to_amount,
        currency_id: txn.to_currency_id,
        account_id_not: txn.to_account_id,
        txdest: txn.txdest,
        txhash: txn.txhash,
        importer_tag: txn.importer_tag,
        fiat: txn.fiat_deposit?
      )
    elsif txn.withdrawal?
      find_txn(
        user,
        date: txn.date,
        amount: txn.from_amount,
        currency_id: txn.from_currency_id,
        account_id_not: txn.from_account_id,
        txdest: txn.txdest,
        txhash: txn.txhash,
        importer_tag: txn.importer_tag,
        fiat: txn.fiat_withdrawal?
      )
    end
  end

  # find a txn that matches the specified params, to find a withdrawal set amount to negative
  # otherwise it will look for deposits
  def find_txn(user, attrs)
    attrs[:txhash] = TxnBuilder::Helper.normalize_hash(attrs[:txhash]) if attrs[:txhash]

    return find_special_match(user, attrs) if attrs[:txhash]&.in?(SPECIAL_TXHASHES)

    return if attrs[:fiat] # we only support fiat transfers between coinbase and cb pro

    match = find_match_on_txhash(user, attrs)
    return match if match

    match = find_match_on_missing_txhash(user, attrs)
    return match if match

    find_match_on_different_txhashes(user, attrs)
  end

  private

  def build_txn_query(user, attrs, high_interval, low_interval, deviation)
    q = user.txns.not_deleted.not_ignored.where(label: nil)
    if attrs[:amount] < 0
      q = q.where(type: [Transaction::FIAT_WITHDRAWAL, Transaction::CRYPTO_WITHDRAWAL])
        .where(from_currency_id: attrs[:currency_id])
        .where('date <= ?', attrs[:date] + high_interval)
        .where('date >= ?', attrs[:date] - low_interval)
        .order(date: :desc)

      if attrs[:account_id_not].present?
        q = q.where.not(from_account_id: attrs[:account_id_not])
      elsif attrs[:account_id_eq].present?
        q = q.where(from_account_id: attrs[:account_id_eq])
      else
        raise TxnBuilder::Helper, "must set either account_id_eq or account_id_not when matching transfers!"
      end

      deviation = attrs[:max_deviation] ? [attrs[:max_deviation], deviation].min : deviation
      min = attrs[:amount].abs
      min -= 0.0000_0001 if deviation > 0 # this allows matching 0.0000_1111 -> 0.0000_1111_11
      max = attrs[:amount].abs + deviation
      q = q.where('from_amount >= ? AND from_amount <= ?', min, max)
    else
      q = q.where(type: [Transaction::FIAT_DEPOSIT, Transaction::CRYPTO_DEPOSIT])
        .where(to_currency_id: attrs[:currency_id])
        .where('date >= ?', attrs[:date] - high_interval)
        .where('date <= ?', attrs[:date] + low_interval)
        .order(date: :asc)

      if attrs[:account_id_not].present?
        q = q.where.not(to_account_id: attrs[:account_id_not])
      elsif attrs[:account_id_eq].present?
        q = q.where(to_account_id: attrs[:account_id_eq])
      else
        raise TxnBuilder::Helper, "must set either account_id_eq or account_id_not when matching transfers!"
      end

      deviation = attrs[:max_deviation] ? [attrs[:max_deviation], deviation].min : deviation
      min = attrs[:amount]
      min += 0.0000_0001 if deviation > 0 # this allows matching 0.0000_1111 -> 0.0000_1111_11
      max = attrs[:amount] - deviation
      q = q.where('to_amount <= ? AND to_amount >= ?', min, max)
    end

    q
  end

  def find_special_match(user, attrs)
    # transfers from gdax can sometimes arrive on coinbase before the actual withdrawal
    txns = build_txn_query(user, attrs, 1.hour, 1.hour, 0).where(txhash: attrs[:txhash]).limit(10)
    select_best_result user, txns, attrs
  end

  def find_match_on_txhash(user, attrs)
    return unless attrs[:txhash].present?
    # a deposit might be created before a withdrawal on some exchanges (coinbase/kraken) so we
    # look for withdrawals even an hour after the deposit as long as txhash matches
    # allow 95% deviation so small coin transfers that have large withdrawal fees can match up,
    # popular coin fees are hardcoded
    # we will reject matches with a fiat fee difference that is too high
    max_fees = max_txn_fees(attrs[:currency_id], attrs[:amount].abs, 0.95)
    txns = build_txn_query(user, attrs, 1.hour, 7.days, max_fees).where(txhash: attrs[:txhash]).limit(10)
    select_best_result user, txns, attrs
  end

  def find_match_on_missing_txhash(user, attrs)
    # for unique amounts we can search up to 7 days ahead
    max_date = attrs[:amount].abs.to_s.gsub(/\.|0/, '').chars.uniq.count > 2 ? 7.days : 24.hours

    # only match with txns that dont have a hash if this one does (unless ignoreable tag) and any if it doesnt
    max_fees = max_txn_fees(attrs[:currency_id], attrs[:amount].abs, 0.15) # allow 15% deviation
    txns = build_txn_query(user, attrs, 10.minutes, max_date, max_fees)

    txhash = BAD_TXHASH_TAGS.include?(attrs[:importer_tag]) ? nil : attrs[:txhash]
    if txhash
      txns = txns.where('txhash IS NULL OR importer_tag IN (?)', BAD_TXHASH_TAGS)
    end

    select_best_result user, txns.limit(10), attrs
  end

  def find_match_on_different_txhashes(user, attrs)
    max_fees = max_txn_fees(attrs[:currency_id], attrs[:amount].abs, 0.05) # allow 5% deviation
    txns = build_txn_query(user, attrs, 1.hour, 1.hour, max_fees).limit(10)
    select_best_result user, txns, attrs
  end

  def select_best_result(user, txns, attrs)
    txns = txns.to_a

    # dont want to match with any special hashes - these should only match when both hashes are same
    txns.reject! { |x| x.txhash&.in?(SPECIAL_TXHASHES) } unless attrs[:txhash]&.in?(SPECIAL_TXHASHES)

    txns.reject! do |x|
      if attrs[:importer_tag].present? && attrs[:importer_tag] == x.importer_tag
        if x.txhash && attrs[:txhash]
          # dont match if txhashes are different but the importer tags are same
          # ex. eth tag shouldnt match with another eth tag if hashes are different
          next true if x.txhash != attrs[:txhash]
        elsif !x.txhash && !attrs[:txhash]
          # for some blockchains like stellar we dont have a txhash but we do have
          # the source and destination address so check if they match
          if attrs[:txsrc] && x.txsrc
            next true if x.txsrc != attrs[:txsrc]
          elsif attrs[:txdest] && x.txdest
            next true if x.txdest != attrs[:txdest]
          end
        end
      end

      # sometimes a txhash can match even though the transactions are different, this usually
      # happens when the sender or receiver splits the transaction in 2 ex:
      #   sent 20 ADA with txhash 0x1234
      #   received 15 ADA with txhash 0x1234  <--- we would match with this one and assume a fee of 0.5 BTC which is wrong
      #   received 5 ADA with txhash 0x4556
      if attrs[:txhash].present? && x.txhash == attrs[:txhash]
        amount = x.from_amount > 0 ? x.from_amount : x.to_amount
        diff = (amount - attrs[:amount].to_d.abs).abs
        if diff > (amount * 0.15) && x.net_value.present? && x.net_value > 0
          usd_value = Rate.convert_amount(x.net_value, user.base_currency, Currency.usd, x.date)
          fee_value = usd_value / amount * diff
          next true if fee_value > 100 # more than 100 USD isnt a fee
        end
      end
    end

    # we prioritize dates in the right and wrong dir differently
    # wrong dir is when a withdrawal is dated after the deposit and vice versa
    right_dir = txns.select { |x| attrs[:amount] < 0 ? x.date <= attrs[:date] : x.date >= attrs[:date] }
    wrong_dir = txns - right_dir

    amount_field = attrs[:amount] < 0 ? :from_amount : :to_amount

    [
      # 1. txhash + closest amount (ignore date in either dir)
      txns.select { |x| attrs[:txhash].present? && x.txhash == attrs[:txhash] }.sort_by { |x| (x.send(amount_field) - attrs[:amount].abs).abs },
      # 2. amount +/- 0.0000_0001 between 0.minutes to 2.hour
      right_dir.select { |x| (x.date - attrs[:date]).abs < 2.hours }.sort_by { |x| (x.send(amount_field) - attrs[:amount].abs).abs },
      # 3. amount +/- 0.0000_0001 between -10.minutes to 0.minutes
      wrong_dir.select { |x| (x.date - attrs[:date]).abs < 10.minutes }.sort_by { |x| (x.send(amount_field) - attrs[:amount].abs).abs },
      # 4. closest date in right dir
      right_dir.sort_by { |x| (x.date - attrs[:date]).abs },
      # 5. closest date in wrong dir
      wrong_dir.sort_by { |x| (x.date - attrs[:date]).abs },
    ].find { |x| x.first }&.first
  end

  def max_txn_fees(currency_id, amount, deviation)
    @fees_by_id ||= MAX_TXN_FEES.inject({}) do |memo, (k, v)|
      id = Currency.find_by(symbol: k)&.id
      memo[id] = v if id
      memo
    end

    [@fees_by_id[currency_id], amount * deviation].compact.min
  end
end
