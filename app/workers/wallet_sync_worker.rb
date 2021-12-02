class WalletSyncWorker < BaseWorker
  include WorkerStatusTracker
  sidekiq_options lock: :until_executed, unique_across_queues: true, queue: :api_import

  def self.current_user(*args)
    Wallet.find_by(id: args[0]).try :user
  end

  def process(wallet_id)
    wallet = Wallet.find_by id: wallet_id
    return unless wallet
    wallet.sync
    UpdateUserStatsWorker.perform_later(wallet.user_id)
  end
end
