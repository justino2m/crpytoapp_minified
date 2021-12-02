class UpdateUserStatsWorker < BaseWorker
  include WorkerStatusTracker
  sidekiq_options(
    queue: :gains_updater,
    lock: :until_and_while_executing,
    unique_across_queues: true,
    on_conflict: { server: :reschedule },
    unique_args: ->(args) { [args.first] } # only uses user_id for uniqueness, other args are ignored
  )

  def self.current_user(*args)
    User.find(args[0])
  end

  # since this worker can take a long time we use this method to determine if we should quit,
  # we dont want to run queries all the time so theres a 5 second guard
  def poll(check_last_txn=true)
    @last_called_at ||= Time.now
    if @last_called_at < 5.seconds.ago
      if UpdateUserStatsWorker.queued?(@user.id) || (check_last_txn && last_transaction_changed?)
        raise QuitWorkerSignal
      end
      @last_called_at = Time.now
    end
  end

  def last_transaction_changed?
    # this was taking up a lot of pg execution time so need to optimize indexes before using id, see user.txns.order(id: :desc).limit(1).explain
    # @user.txns.order(id: :desc).limit(1).pluck(:id).first || 0
    count = @user.txns.count
    @last_txn ||= count
    @last_txn != count
  end

  # IMPORTANT: ANY CHANGES TO THESE ARGUMENTS MUST BE REFLECTED IN CALLS TO QUEUED? AND RUNNING?
  def process(user_id, override_allowance=false)
    @user = User.find(user_id)

    WalletCleanup.call(@user)
    RebuildUserInvestments.call(@user) if @user.rebuild_scheduled?

    return if @user.gains_blocked? && !override_allowance

    TransferMatcher.call(@user) { poll(false) } # this can change txn count so we dont check
    EntryBalanceUpdater.call(@user) { poll }
    InvestmentsUpdater.call(@user) { poll }
    AssetsUpdater.update(@user) { poll }

    oldest_date = @user.investments.ordered.first.try(:date) # this is using the ordered index otherwise its very slow!
    if oldest_date
      SnapshotsUpdater.call(@user, oldest_date.to_datetime..DateTime.now, false) { poll }
    else
      @user.snapshots.delete_all
    end
  # rescue QuitWorkerSignal # note: this is being handled inside WorkerStatusTracker so user doesnt see a success message when worker quits
  end
end
