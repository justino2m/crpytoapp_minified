# for logging activerecord calls to console
if Rails.env.development? && Sidekiq.server?
  Rails.logger = Sidekiq::Logging.logger
  ActiveRecord::Base.logger = Sidekiq::Logging.logger
  Sidekiq::Logging.logger.level = 0
end