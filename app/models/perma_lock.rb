class PermaLock < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  scope :stale, ->() { where('stale_at < ?', Time.now) }
  scope :active, ->() { where('stale_at > ?', Time.now) }

  class LockTimeout < RuntimeError; end

  def self.lock(object, opt={})
    timeout = opt.delete(:wait)
    if timeout && timeout > 0
      timeout_at = Time.now + timeout
      while !timeout_at.past?
        if lk = acquire_lock(object, opt)
          return lk
        else
          sleep(0.5)  # poll every half second
        end
      end
    else
      acquire_lock(object, opt)
    end
  end

  def self.lock!(object, opt={})
    lock(object, opt) || raise_lock_error(object)
  end

  def self.with_lock!(object, opt={})
    lk = lock!(object, opt)
    begin
      yield
    ensure
      lk.destroy
    end
  end

  def self.locked?(object)
    PermaLock.active.where(name: lock_name(object)).exists?
  end

  private

  def self.lock_name(object)
    (object.try(:to_global_id) || object).to_s
  end

  def self.acquire_lock(object, opt={})
    stale.delete_all

    opt[:stale_at] ||= 10.minutes.from_now
    begin
      create!(opt.merge(name: lock_name(object)))
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
      # we consume only these exceptions, raise everything else (BusyException etc)
    end
  end

  def self.raise_lock_error(object)
    if object.is_a? ActiveRecord::Base
      title = "#{object.class.name}[#{object.id}]"
    else
      title = object.to_s
    end
    raise LockTimeout.new "#{title} is locked!"
  end
end
