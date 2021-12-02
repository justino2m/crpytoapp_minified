module TxnBuilder
  class Withdrawal < Base
    validates_presence_of :from_amount, :from_currency
    validates :from_amount, numericality: { greater_than: 0 }

    def create!
      if group_name
        create_or_merge_grouped_txn(type: txn_type, from_entry: from_entry)
      else
        return if duplicate?

        txn = TransferMatcher.find_txn(
          current_user,
          date: date,
          amount: from_amount,
          currency_id: from_currency.id,
          account_id_not: from_account.id,
          txhash: txhash,
          importer_tag: importer_tag
        ) unless label.present? || adapter.importing

        if txn
          ActiveRecord::Base.transaction do
            txn.description ||= description
            txn.merge_transfer_entries!([Entry.new(from_entry)])
            txn
          end
        else
          create_transaction(type: txn_type, from_entry: from_entry)
        end
      end
    end

    private

    def duplicate?
      return false if allow_duplicates
      if external_id
        q = { account_id: from_account.id, external_id: external_id }
        return pending_entry?(q) || current_user.entries.not_deleted.where(q).exists?
      end

      return true if txhash && !allow_txhash_conflicts && loose_duplicate?(from_entry, txhash)
      loose_duplicate?(from_entry)
    end

    def txn_type
      from_currency.fiat? ? Transaction::FIAT_WITHDRAWAL : Transaction::CRYPTO_WITHDRAWAL
    end
  end
end
