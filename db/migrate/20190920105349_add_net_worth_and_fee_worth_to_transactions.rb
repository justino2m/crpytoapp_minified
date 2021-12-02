class AddNetWorthAndFeeWorthToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :net_worth_amount, :decimal
    add_reference :transactions, :net_worth_currency, foreign_key: { to_table: :currencies }
    add_column :transactions, :fee_worth_amount, :decimal
    add_reference :transactions, :fee_worth_currency, foreign_key: { to_table: :currencies }
  end

  def backfill_worths
    txns = []
    Transaction.includes(user: :base_currency).find_each(batch_size: 2000) do |txn|
      if txn.metadata.dig(:worth, :currency_id).present?
        txn.net_worth_amount = txn.metadata.dig(:worth, :amount).to_d
        txn.net_worth_currency_id = txn.metadata.dig(:worth, :currency_id)
        txn.metadata.delete(:worth)
      end

      if txn.metadata.dig(:fee_worth, :currency_id).present?
        txn.fee_worth_amount = txn.metadata.dig(:fee_worth, :amount).to_d
        txn.fee_worth_currency_id = txn.metadata.dig(:fee_worth, :currency_id)
        txn.metadata.delete(:fee_worth)
      end

      if txn.metadata.dig(:rates).present?
        unless txn.metadata[:rates].first[1].is_a? Hash
          old_rates = txn.metadata.delete(:rates)
          base_curr = txn.user.base_currency.symbol
          txn.metadata[:rates] = { base_curr => {} }
          old_rates.each do |k, v|
            txn.metadata[:rates][base_curr][k] = v
          end
        end
      end

      if txn.changed?
        txns << txn
        commit_txns(txns) if txns.count >= 2000
      end
    end

    commit_txns(txns)
  end

  def revert_backfill
    txns = []
    Transaction.includes(user: :base_currency).find_each do |txn|
      if txn.metadata.dig(:rates).present?
        base = txn.user.base_currency.symbol
        begin
          txn.metadata[:rates] = txn.metadata[:rates][base] if txn.metadata[:rates].first[1].is_a?(Hash)
          txn.metadata[:rates] = txn.metadata[:rates][base] if txn.metadata[:rates].first[1].is_a?(Hash)
          txn.metadata[:rates] = txn.metadata[:rates][base] if txn.metadata[:rates].first[1].is_a?(Hash)
          txn.metadata[:rates] = txn.metadata[:rates][base] if txn.metadata[:rates].first[1].is_a?(Hash)
          txn.metadata[:rates] = txn.metadata[:rates][base] if txn.metadata[:rates].first[1].is_a?(Hash)
        rescue => e
          byebug
        end
      end

      if txn.changed?
        txns << txn
        commit_txns(txns) if txns.count > 1000
      end
    end

    commit_txns(txns)
  end

  def commit_txns(txns)
    Transaction.import(txns, on_duplicate_key_update: [:net_worth_amount, :net_worth_currency_id, :fee_worth_amount, :fee_worth_currency_id, :metadata], validate: false)
    txns.clear
  end
end
