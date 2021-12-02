class RebuildUserInvestments
  def self.call(user)
    user.investments.delete_all
    user.snapshots.delete_all
    # user.entries.update_all(balance: nil) # very slow query on db, we dont really need this unless something went wrong...

    # this handles changes to base currency
    user.txns
      .includes(:from_currency, :to_currency, :fee_currency, :net_worth_currency, :fee_worth_currency)
      .find_in_batches(batch_size: 500) do |batch|
      txns = []
      batch.each do |txn|
        txn.update_totals
        txn.gain = nil
        txns << txn
      end
      Transaction.import(
        txns,
        on_duplicate_key_update: [:missing_rates, :net_value, :fee_value, :cached_rates, :gain],
        validate: false
      )
    end

    user.update_attributes!(rebuild_scheduled: false)
  end
end
