class EntryBalanceUpdater
  def self.call(user)
    new.call(user) { yield if block_given? }
  end

  def call(user)
    return unless user.entries.pending_balance.exists?
    user.accounts.pluck(:id).each do |account_id|
      yield if block_given?

      entries_query = Entry.where(account_id: account_id)

      # select earliest date
      date = entries_query.pending_balance.pluck(Arel.sql('min(date)')).first
      next unless date

      ActiveRecord::Base.transaction do
        entries_query.pending_deletion.delete_all # there wont be any deletable entries if date is nil
        entries_query.where('date >= ?', date).where.not(balance: nil).update_all(balance: nil)
      end

      entries = []
      balance = nil
      lowest = nil

      # update balance of all entries after this date (even if balance is not nil for them)
      BatchLoad.call(entries_query.ordered.where('date >= ?', date), 500) do |entry|
        yield if block_given?
        if entry.ignored?
          entry.balance = 0
          entry.negative = false
          entries << entry if entry.changed?
        else
          balance ||= Entry.earlier_than(entry).where(account_id: account_id).not_ignored.sum(:amount)
          lowest ||= Entry.earlier_than(entry).where(account_id: account_id).not_ignored.where('balance < 0').minimum(:balance) || 0
          balance += entry.amount
          negative = balance <= -0.0000_0001 && balance < lowest
          lowest = balance if negative
          if entry.balance != balance || entry.negative != negative
            entry.balance = balance
            entry.negative = negative
            entries << entry
            commit_entries(entries) if entries.count > 1000
          end
        end
      end
      commit_entries(entries)
    end

    # no warnings for negative fiat balances
    negative_txns = user.entries.joins(account: :currency).where(negative: true, currencies: { fiat: false }).distinct.select(:transaction_id)
    user.txns.where(id: negative_txns).where(negative_balances: false).update_all(negative_balances: true)
    user.txns.where.not(id: negative_txns).where(negative_balances: true).update_all(negative_balances: false)
  end

  def commit_entries(entries)
    Entry.import(entries, on_duplicate_key_update: [:balance, :negative], validate: false) if entries.any?
    entries.clear
  end
end
