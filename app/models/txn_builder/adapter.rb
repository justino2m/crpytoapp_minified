module TxnBuilder
  class Adapter
    attr_accessor :current_user, :current_wallet, :importing, :pending_txns, :pending_entries, :initialized_at

    PENDING_TXN_BATCH_SIZE = 500
    PENDING_ENTRIES_BATCH_SIZE = 5000

    def initialize(current_user, current_wallet, importing)
      @current_user = current_user
      @current_wallet = current_wallet
      @importing = importing
      @initialized_at = Time.now
      @pending_txns = []
      @pending_entries = []
    end

    # the entries must be explicitly passed into this method to avoid creating entries accidentally
    def create_transaction(
      type:,
      date:,
      label:,
      description:,
      txhash:,
      txsrc:,
      txdest:,
      margin: false,
      importer_tag:,
      net_worth_amount:,
      net_worth_currency:,
      fee_worth_amount:,
      fee_worth_currency:,
      from_entry: nil,
      to_entry: nil,
      fee_entry: nil,
      group_name: nil,
      group_date: nil,
      group_from: nil,
      group_to: nil,
      group_count: nil
    )
      txn = Transaction.new(
        user: current_user,
        type: type,
        date: date,
        label: label,
        description: description,
        from_wallet_id: from_entry.try(:dig, :account)&.wallet_id,
        to_wallet_id: to_entry.try(:dig, :account)&.wallet_id,
        from_account: from_entry.try(:dig, :account),
        to_account: to_entry.try(:dig, :account),
        fee_account: fee_entry.try(:dig, :account),
        net_worth_amount: net_worth_amount,
        net_worth_currency: net_worth_currency,
        fee_worth_amount: fee_worth_amount,
        fee_worth_currency: fee_worth_currency,
        txhash: txhash,
        txsrc: txsrc,
        txdest: txdest,
        importer_tag: importer_tag,
        margin: margin,
        group_name: group_name,
        group_date: group_date,
        group_from: group_from,
        group_to: group_to,
        group_count: group_count
      )

      [from_entry, to_entry, fee_entry].compact.each do |attr|
        entry = Entry.new(attr.merge(user: current_user))
        txn.entries << entry
        pending_entries << entry
      end

      txn.update_from_entries
      raise TxnBuilder::Error.new(txn) unless txn.valid?
      txn.update_totals

      if importing
        self.pending_txns << txn
        commit! if pending_txns.count > PENDING_TXN_BATCH_SIZE || pending_entries.count > PENDING_ENTRIES_BATCH_SIZE
      else
        txn.save!
        txn.update_account_totals!
      end

      txn
    end

    def commit!
      return unless pending_txns.any?
      # this import takes 3 seconds on average for 1000 txns
      ActiveRecord::Base.transaction do
        Transaction.import(pending_txns, validate: false, recursive: true)
      end
      pending_txns.clear
      pending_entries.clear
      update_accounts!
    end

    def update_accounts!
      account_ids = current_user.entries.where('updated_at >= ?', @initialized_at).distinct.pluck(:account_id)
      current_user.accounts.where(id: account_ids).each(&:update_totals!) if account_ids.any?
    end

    def fetch_account(currency, wallet = nil)
      @accounts ||= {}
      wallet ||= current_wallet
      @accounts["#{wallet.id}_#{currency.id}"] ||= begin
        account = wallet.accounts.where(currency: currency).first_or_create!(user: current_user)
        account.currency = currency # to avoid pulling it from db later
        account
      end
    end

    # use this lookup currencies by id or symbol, if using symbol you can also
    # specify an array of preferred currency ids that we will prioritize from
    # in case of duplicate symbols, without this array we will pick the most
    # traded symbol
    def fetch_currency(importer_tag, preferred_ids: nil, raise: false, id: nil, symbol: nil, name: nil, fiat: nil, added_by_user: nil)
      if id.present?
        @currencies_by_id ||= {}
        @currencies_by_id[id] ||= Currency.find(id)
      elsif symbol.blank?
        raise TxnBuilder::Error, "Must provide a symbol or id for currency!"
      else
        symbol = symbol.strip.upcase # dont change original string!
        @currencies ||= {}
        @currencies[symbol] ||=
          resolve_from_string_id(symbol) ||
          resolve_symbol_alias(importer_tag, symbol) ||
          find_currency_by_symbol(importer_tag, symbol, preferred_ids: preferred_ids, raise: raise, name: name, fiat: fiat, added_by_user: added_by_user)
      end
    end

    def resolve_symbol_alias(importer_tag, symbol)
      @symbol_aliases ||= {}
      key = "#{importer_tag}_#{symbol}"
      if @symbol_aliases[key].nil?
        @symbol_aliases[key] =
          SymbolAlias.find_by(symbol: symbol, tag: importer_tag) ||
          SymbolAlias.find_by(symbol: symbol, tag: SymbolAlias::COMMON_TAG) ||
          false
      end
      @symbol_aliases[key].currency unless @symbol_aliases[key] == false
    end

    #   crypto symbol same as fiat symbol - we give prio to the crypto symbol in such cases
    #   duplicate crypto symbols - we are using prioritized to select the most traded one
    def find_currency_by_symbol(importer_tag, symbol, preferred_ids: nil, raise: false, name: nil, fiat: nil, added_by_user: nil)
      return Currency.fiat.find_by(symbol: symbol) if fiat
      attrs = { symbol: symbol }
      attrs[:fiat] = fiat unless fiat.nil?
      attrs[:added_by_user] = added_by_user unless added_by_user.nil?
      matches = Currency.where(attrs).to_a

      if matches.none?
        raise TxnBuilder::Error, "Currency with symbol = #{symbol} not found for #{importer_tag}!" if raise
      else
        return matches[0] unless preferred_ids.present? || name.present?
        found = matches.find { |match| preferred_ids.include?(match.id) } if preferred_ids.present?
        return found if found
        found = matches.find { |match| match.name.downcase.match(name.downcase) } if name.present?
        found
      end
    end

    # this allows users to enter the currency id when a symbol has duplicate symbols
    # ID:1234
    def resolve_from_string_id(symbol)
      match = symbol.match(/^ID:([0-9]+)$/)
      Currency.find_by(id: match[1].to_i) if match
    end

    def pending_entry?(q)
      !!find_pending_entry(q)
    end

    def pending_txn?(q)
      !!find_pending_txn(q)
    end

    def find_pending_entry(q)
      # must search in reverse order as trades can create multiple txns with the same txhash when too many entries
      pending_entries.reverse_each.find { |e| matched?(e, q) }
    end

    def find_pending_txn(q)
      pending_txns.reverse_each.find { |txn| matched?(txn, q) }
    end

    def matched?(record, attrs)
      attrs.all? do |k, v|
        if v.is_a?(Array)
          v.include?(record[k])
        elsif v.is_a?(ActiveRecord::Base)
          record[k.to_s + "_id"] == v.id
        elsif v.is_a?(Range)
          record[k].in?(v)
        else
          record[k] == v
        end
      end
    end
  end
end
