module TxnBuilder
  class FeesInMultipleCurrencies < StandardError
  end

  class FromAndToAreSameDirection < StandardError
  end

  class InvalidTransferMerge < StandardError
  end

  class Merger
    attr_accessor :txn

    def initialize(txn)
      self.txn = txn
    end

    def unmerge_entries!(account_id, update_account_bals = true)
      raise "cant unmerge #{txn.type}" unless txn.transfer? || txn.trade?

      txn.label = nil
      txn.importer_tag = nil # will be set by updater
      txn.txhash = nil if txn.entries.any?(&:txhash)
      txn.entries.where("account_id = ? OR adjustment IS TRUE OR fee IS TRUE", account_id).soft_delete!

      merge_entries! [], update_account_bals
    end

    def merge_entries!(entries, update_accounts = true)
      entries.map do |x|
        entry = x.is_a?(Entry) ? x : Entry.new(x)
        entry.id = nil
        entry.user_id = txn.user_id
        entry.transaction_id = txn.id
        txn.entries << entry # this persists them too
      end

      txn.entries.reload # must reload to avoid weird issues for ex. if 2 wallets are deleted at same time
      if txn.entries.any?
        update_from_entries
        txn.update_totals
        txn.save!
        txn.update_account_totals! if update_accounts
      else
        txn.update_columns from_account_id: nil, to_account_id: nil, fee_account_id: nil
      end
    end

    # for transfers we have to create separate entries for the fees,
    # we create one fee entry and one adjustment which removes the fee from
    # the from_amount. This way we dont have to modify any original entries
    # and can delete the adjustments when the txn is unmerged
    def merge_transfer_entries!(entries)
      update_from_entries(entries)
      raise InvalidTransferMerge, "not a transfer" unless txn.transfer?
      raise TxnBuilder::Error.new(txn) unless txn.valid?

      fee = txn.from_amount - txn.to_amount
      if fee > 0
        fee_entry = {
          amount: -fee,
          account_id: txn.from_account_id,
          date: txn.date,
          fee: true,
        }
        entries << fee_entry

        # we have to reduce from_amount without touching the from entry. this is done by creating
        # a positive 'adjustment' entry that is same as the fee
        entries << fee_entry.dup.merge(amount: fee, fee: false, adjustment: true)
      end

      merge_entries!(entries)
    end

    def merge_txn!(other, is_transfer)
      return false unless other

      if txn.net_worth_currency_id.nil?
        txn.net_worth_amount = other.net_worth_amount
        txn.net_worth_currency_id = other.net_worth_currency_id
      end

      if txn.fee_worth_currency_id.nil?
        txn.fee_worth_amount = other.fee_worth_amount
        txn.fee_worth_currency_id = other.fee_worth_currency_id
      end

      ActiveRecord::Base.transaction do
        entries = other.entries.map(&:dup)
        other.destroy! # delete first so the account totals are correct after merger
        if is_transfer
          merge_transfer_entries!(entries)
        else
          merge_entries!(entries)
        end
      end

      true
    end

    # do not query entries from db in this method as some might not have been persisted when it is called
    # ex. when bulk importing via api
    def update_from_entries(new_entries = [])
      entries = txn.entries.to_a + new_entries
      txn.from_account_id, txn.to_account_id, txn.fee_account_id = determine_account_ids(entries)
      txn.from_wallet_id = txn.from_account&.wallet_id if txn.from_account_id_changed?
      txn.to_wallet_id = txn.to_account&.wallet_id if txn.to_account_id_changed?
      txn.from_currency_id = txn.from_account&.currency_id if txn.from_account_id_changed? || txn.from_currency_id_changed?
      txn.to_currency_id = txn.to_account&.currency_id if txn.to_account_id_changed? || txn.to_currency_id_changed?
      txn.fee_currency_id = txn.fee_account&.currency_id if txn.fee_account_id_changed? || txn.fee_currency_id_changed?

      txn.from_amount = entries.select { |e| e.account_id == txn.from_account_id && !e.fee? }.sum(&:amount).abs
      txn.to_amount = entries.select { |e| e.account_id == txn.to_account_id && !e.fee? }.sum(&:amount).abs
      txn.fee_amount = entries.select { |e| e.account_id == txn.fee_account_id && e.fee? }.sum(&:amount).abs

      txn.type = determine_txn_type

      if txn.from_wallet_id && txn.to_wallet_id && txn.from_wallet_id != txn.to_wallet_id
        # the receiving wallet should be seen as the source of truth for the date since user would
        # be able to trade with the received funds after this date.
        # note: 'sending' wallets can sometimes use date from blockchain (ex. ledger) and so the send
        # date might be higher than the received date
        txn.date = entries.select { |e| e.account_id == txn.to_account_id && !e.fee? }.map(&:date).sort.first
      else
        # when there are multiple entries we want the date for the earliest one, this takes care of issues
        # in case user traded with the proceeds of this trade
        txn.date = entries.sort_by(&:date).first.date
      end

      txn.from_source = determine_source(txn.from_account_id, entries)
      txn.to_source = determine_source(txn.to_account_id, entries)
      txn.importer_tag ||= entries.find { |x| x.importer_tag.present? }&.importer_tag
      txn.txhash ||= entries.find { |x| x.txhash.present? }&.txhash # hash may be edited by user so dont override
      true
    end

    def determine_account_ids(entries)
      fee_account_ids = entries.select(&:fee?).map(&:account_id).uniq
      raise FeesInMultipleCurrencies, "fees in multiple currencies on txn #{txn.id}" if fee_account_ids.count > 1

      account_ids = entries.reject(&:fee?).map(&:account_id).uniq
      amount1 = entries.select { |e| e.account_id == account_ids[0] && !e.fee? }.sum(&:amount)
      amount2 = entries.select { |e| e.account_id == account_ids[1] && !e.fee? }.sum(&:amount) if account_ids[1]
      raise FromAndToAreSameDirection, "both from/to are #{amount1.negative? ? "negative" : "positive"} in txn #{txn.id}" if amount2 && amount1.negative? == amount2.negative?

      from_account_id = to_account_id = nil
      [[amount1, account_ids[0]], [amount2, account_ids[1]]].each do |(amount, account_id)|
        next unless account_id.present?
        if amount > 0
          to_account_id = account_id
        else
          from_account_id = account_id
        end
      end

      [from_account_id, to_account_id, fee_account_ids.first]
    end

    def determine_txn_type
      if txn.from_currency_id.present? && txn.to_currency_id.present?
        if txn.from_currency_id == txn.to_currency_id
          Transaction::TRANSFER
        elsif txn.from_currency.fiat? && txn.to_currency.fiat?
          Transaction::EXCHANGE
        elsif txn.from_currency.crypto? && txn.to_currency.crypto?
          Transaction::EXCHANGE
        elsif txn.from_currency.fiat?
          Transaction::BUY
        else
          Transaction::SELL
        end
      else
        if txn.from_currency
          txn.from_currency.fiat? ? Transaction::FIAT_WITHDRAWAL : Transaction::CRYPTO_WITHDRAWAL
        else
          txn.to_currency.fiat? ? Transaction::FIAT_DEPOSIT : Transaction::CRYPTO_DEPOSIT
        end
      end
    end

    def determine_source(account_id, entries)
      return nil unless account_id
      selected = entries.select { |e| e.account_id == account_id && !e.fee? && !e.adjustment? }
      return 'api' if selected.all?(&:synced)
      return 'csv' if selected.none?(&:manual?)
      nil
    end
  end
end
