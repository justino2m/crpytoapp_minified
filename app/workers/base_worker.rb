class BaseWorker
  include Sidekiq::Worker

  def self.uniq_id(suffix, *args)
    uniq_digest = SidekiqUniqueJobs::UniqueArgs.digest("class" => self.name, "args" => args)
    uniq_digest + suffix
  end

  def self.running?(*args)
    Sidekiq.redis{ |red| red.exists(uniq_id(':RUN:EXISTS', *args)) || red.exists(uniq_id(':RUN', *args)) }
  end

  def self.queued?(*args)
    Sidekiq.redis{ |red| red.exists(uniq_id(':EXISTS', *args)) || red.exists(uniq_id('', *args)) }
  end

  def self.perform_later(*args)
    perform_async(*args)
  end

  def self.perform_now(*args)
    new.perform(*args)
  end

  def reschedule_in(*args)
    self.class.perform_in(*args)
  end
end