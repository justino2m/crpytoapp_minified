module TxnBuilder
  class Trade < Base
    MAX_TRADES_PER_ORDER = 200

    validates_presence_of :from_amount, :from_currency, :to_amount, :to_currency
    validates :to_amount, numericality: { greater_than: 0 }
    validates :from_amount, numericality: { greater_than: 0 }
    validate :ensure_from_and_to_not_same

    def initialize(user, wallet, params, adapter = nil)
      super
      self.label = nil unless label&.in?(Transaction::TRADE_LABELS)
    end

    def create!
      return if duplicate?
      # add entries to an existing transaction if possible. this can be the
      # case when an order is executed in multiple intervals/trades. we want
      # to show a single transaction for such cases as it makes more sense
      # to a user instead of multiple ones that are part of the same order.
      if existing_txn && adapter.importing && (external_id.present? || !allow_txhash_conflicts)
        # entries might not be persisted so dont query db
        return existing_txn if external_id.nil? || existing_txn.entries.any? { |e| e.external_id == external_id }

        # only group trades that happen within an hour of each other as prices can change after that
        first_date = existing_txn.entries.sort_by(&:date).map(&:date)[0]

        # some txns can have thousands of entries in which case we want to create new txns instead of adding to existing
        # .count fetches from db so must use .length here
        if existing_txn.entries.length < MAX_TRADES_PER_ORDER && (first_date - from_entry[:date]).abs < 2.hours
          [from_entry, to_entry, fee_entry].compact.each do |attr|
            entry = Entry.new(attr.merge(user: current_user))
            existing_txn.entries << entry
            adapter.pending_entries << entry unless existing_txn.persisted?
          end

          # the net worth amount cant be valid after a merge
          existing_txn.net_worth_currency_id = nil
          existing_txn.net_worth_amount = 0
          existing_txn.fee_worth_currency_id = nil
          existing_txn.fee_worth_amount = 0

          existing_txn.description = description if existing_txn.description.blank?
          existing_txn.update_from_entries
          existing_txn.update_totals
          existing_txn.save! if existing_txn.persisted? # dont save pending txn
          return existing_txn
        end
      end

      create_transaction(
        type: txn_type,
        from_entry: from_entry,
        to_entry: to_entry,
        fee_entry: fee_entry
      )
    end

    private

    def duplicate?
      return false if allow_duplicates
      if external_id
        q = { account_id: [from_account.id, to_account.id], external_id: external_id }
        # its possible for users to create 2 separate orders which have the same id when self-trading (one sell and other buy)
        # this was detected on binance
        q[:txhash] = txhash if txhash.present?
        return pending_entry?(q) || current_user.entries.not_deleted.where(q).exists?
      elsif !allow_txhash_conflicts && txhash
        return existing_txn
      end

      loose_duplicate?(from_entry) && loose_duplicate?(to_entry)
    end

    def ensure_from_and_to_not_same
      return unless from_currency && to_currency
      if from_currency == to_currency
        self.errors.add(:from_currency_id, 'should not be same as To currency')
      end
    end

    def txn_type
      if from_currency.crypto? && to_currency.crypto?
        Transaction::EXCHANGE
      elsif from_currency.fiat?
        Transaction::BUY
      else
        Transaction::SELL
      end
    end

    def existing_txn
      return if allow_duplicates
      q = {
        type: txn_type,
        from_account_id: from_account.id,
        to_account_id: to_account.id,
        txhash: txhash
      }

      q[:fee_account_id] = [nil, fee_account.id] if fee_account

      # need to reverse search so we can find the last txn with this order id (there can be multiple txns for same order when too many entries)
      @existing_txn ||= txhash && (find_pending_txn(q) || current_user.txns.not_deleted.order(id: :desc).find_by(q))
    end
  end
end
