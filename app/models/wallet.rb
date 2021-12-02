class Wallet < ApplicationRecord
  belongs_to :user
  belongs_to :wallet_service, optional: true
  has_many :csv_imports, dependent: :nullify
  has_many :accounts, dependent: :nullify
  has_many :entries, through: :accounts
  has_many :active_accounts, -> { where.not(balance: 0) }, class_name: Account.to_s
  scope :synced, -> { where(api_connected: true) }

  validates_presence_of :name
  validate :validate_api_fields

  after_commit :enqueue_sync_job, on: [:create, :update]
  after_destroy_commit :enqueue_cleanup_job

  serialize :api_options, HashSerializer
  serialize :api_syncdata, HashSerializer

  delegate :api_importer_klass, :api_oauth_url, :api_required_fields, to: :wallet_service, allow_nil: true

  def txns
    Transaction.where(
      "from_account_id IN (:ids) OR to_account_id IN (:ids) OR fee_account_id IN (:ids)",
      ids: accounts.pluck(:id) # pluck is much faster than select here
    )
  end

  # this method is not used anywhere but is useful for debugging
  def api_importer
    api_importer_klass&.new(self, api_options.symbolize_keys)
  end

  def sync
    return unless api_connected
    self.api_syncdata.delete(:last_internal_error)
    self.last_error = nil
    self.last_error_at = nil
    self.auth_failed = false
    self.sync_started_at = Time.now if sync_started_at.nil? || (synced_at && sync_started_at < synced_at)
    api_importer_klass&.process(self, api_options.symbolize_keys)
    true # the ensure block's return value is ignored
  rescue SyncError, TxnBuilder::Error => e
    self.last_error = e.message
    self.last_error_at = Time.now
    self.auth_failed = true if e.is_a? SyncAuthError
    Rollbar.error(e)
  rescue => e
    self.api_syncdata[:last_internal_error] = e.message
    self.last_error = 'Something went wrong while syncing, try again in a few minutes or contact support.'
    self.last_error_at = Time.now
    Rollbar.error(e)
  ensure
    self.synced_at = Time.now
    save!
  end

  def balance_diff
    return nil unless api_syncdata[:balance_diff].present?
    api_syncdata[:balance_diff]
  end

  def clear_transactions!
    accounts.update_all(wallet_id: nil)
    update_attributes!(api_syncdata: nil)
    enqueue_cleanup_job
  end

  private

  def validate_api_fields
    unless api_connected?
      self.api_options = nil
      self.api_syncdata = nil
      return
    end

    (api_required_fields || []).each do |field|
      if api_options[field].blank?
        self.errors.add("api_options[#{field}]", "is missing")
      else
        api_options[field].strip! if api_options[field].is_a?(String)
      end
    end

    if api_options[:deposit_label].present? && !Transaction::CRYPTO_DEPOSIT_LABELS.include?(api_options[:deposit_label])
      errors.add("api_options[deposit_label]", "must be one of #{Transaction::CRYPTO_DEPOSIT_LABELS.join(', ')}")
    end

    if api_options[:withdrawal_label].present? && !Transaction::CRYPTO_WITHDRAWAL_LABELS.include?(api_options[:withdrawal_label])
      errors.add("api_options[withdrawal_label]", "must be one of #{Transaction::CRYPTO_WITHDRAWAL_LABELS.join(', ')}")
    end

    # we only want to set the start date once!
    api_options[:start_date] ||= Time.now.to_s if api_options[:skip_history]
  end

  def enqueue_cleanup_job
    UpdateUserStatsWorker.perform_later(user_id)
  end

  def enqueue_sync_job
    WalletSyncWorker.perform_later(id) if saved_change_to_api_connected && api_connected
  end
end
