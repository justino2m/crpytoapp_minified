class RenameMetadataToCachedRatesInTransactions < ActiveRecord::Migration[5.2]
  def change
    rename_column :transactions, :metadata, :cached_rates
  end

  def backfill_worths
    txns = []
    Transaction.includes(user: :base_currency).find_each(batch_size: 2000) do |txn|
      if txn.cached_rates[:rates].present?
        puts "unknown keys: #{(txn.cached_rates.keys - ['rates', 'rates_v2']).join(', ')}" if (txn.cached_rates.keys - ['rates', 'rates_v2']).any?
        txn.cached_rates = txn.cached_rates.delete(:rates)
        txns << txn
        commit_txns(txns) if txns.count >= 2000
      end
    end

    commit_txns(txns)
  end

  def commit_txns(txns)
    Transaction.import(txns, on_duplicate_key_update: [:cached_rates], validate: false)
    txns.clear
  end
end
