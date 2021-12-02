class JobStatus < ApplicationRecord
  STATUSES = [
    QUEUED = 'queued',
    EXECUTING = 'executing',
    SUCCESS = 'success',
    ERROR = 'error',
  ].freeze

  belongs_to :user
  scope :active, -> { where(status: [QUEUED, EXECUTING]).where('updated_at > ?', 5.hours.ago) }
  before_validation :set_defaults
  validates_presence_of :klass, :status, :args

  def self.find_or_create_matching(user, klass, args)
    user.job_statuses.where(klass: klass, args: args.join('|')).first_or_create!
  end

  def name
    case klass
    when WalletSyncWorker.to_s
      "Syncing #{Wallet.find_by(id: args.to_i).try(:name)}" # it might have been deleted
    when UpdateUserStatsWorker.to_s
      "Updating your gains"
    else
      klass.gsub('Worker', '')
    end
  end

  def executing!
    update_attributes!(status: EXECUTING, updated_at: Time.now)
  end

  def error!
    update_attributes!(status: ERROR, updated_at: Time.now)
  end

  def success!
    update_attributes!(status: SUCCESS, updated_at: Time.now)
  end

  private

  def set_defaults
    self.status ||= QUEUED
  end
end
