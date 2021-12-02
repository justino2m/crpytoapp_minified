class Coupon < ApplicationRecord
  belongs_to :owner, class_name: User.to_s, optional: true
  has_many :discounted_subs, class_name: Subscription.to_s, foreign_key: :discount_coupon_id
  has_many :commission_subs, class_name: Subscription.to_s, foreign_key: :commission_coupon_id
  scope :active, ->{ where("expires_at IS NULL OR expires_at > ?", Time.now) }
  before_create ->{ self.code ||= SecureRandom.hex(4).upcase }

  def self.best_of(user, coupon1, coupon2)
    coupon1 = nil unless coupon1&.active? && coupon1&.eligible?(user)
    coupon2 = nil unless coupon2&.active? && coupon2&.eligible?(user)
    discount1 = coupon1&.calculate_discount(user, 100) || 0
    discount2 = coupon2&.calculate_discount(user, 100) || 0
    return if discount1 <= 0 && discount2 <= 0
    discount1 >= discount2 ? coupon1 : coupon2
  end

  def subscriptions
    Subscription.where('discount_coupon_id = :id OR commission_coupon_id = :id', id: id)
  end

  def active?
    !expired?
  end

  def expired?
    expires_at && expires_at < Time.now
  end

  def deactivate!
    touch(:expires_at)
  end

  def update_usage!
    update_attributes!(usages: subscriptions.count)
  end

  # override this method if needed
  def eligible?(user)
    true
  end

  # override this method
  def calculate_commission(user, amount)
    raise "not implemented"
  end

  # override this method
  def calculate_discount(user, amount)
    raise "not implemented"
  end

  def calculate_discounted_price(user, amount)
    [0, amount - calculate_discount(user, amount)].max
  end

  # these methods are used to show info to the user
  def commission_text
  end

  def recurring_commission_text
  end

  def discount_text
  end
end
