module TxnBuilder
  class Deposit < Base
    validates_presence_of :to_amount, :to_currency
    validates :to_amount, numericality: { greater_than: 0 }

    def create!
      if group_name
        create_or_merge_grouped_txn(type: txn_type, to_entry: to_entry)
      else
        return if duplicate?

        txn = TransferMatcher.find_txn(
          current_user,
          amount: -to_amount,
          date: date,
          currency_id: to_currency.id,
          account_id_not: to_account.id,
          txhash: txhash,
          importer_tag: importer_tag
        ) unless label.present? || adapter.importing

        if txn
          ActiveRecord::Base.transaction do
            txn.description ||= description
            txn.merge_transfer_entries!([Entry.new(to_entry)])
            txn
          end
        else
          create_transaction(type: txn_type, to_entry: to_entry)
        end
      end
    end

    private

    def duplicate?
      return false if allow_duplicates
      if external_id
        q = { account_id: to_account.id, external_id: external_id }
        return pending_entry?(q) || current_user.entries.not_deleted.where(q).exists?
      end

      return true if txhash && !allow_txhash_conflicts && loose_duplicate?(to_entry, txhash)
      loose_duplicate?(to_entry)
    end

    def txn_type
      to_currency.fiat? ? Transaction::FIAT_DEPOSIT : Transaction::CRYPTO_DEPOSIT
    end
  end
end
