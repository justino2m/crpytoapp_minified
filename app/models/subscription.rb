class Subscription < ApplicationRecord
  belongs_to :user
  belongs_to :plan
  belongs_to :commission_coupon, class_name: Coupon.to_s, optional: true
  belongs_to :discount_coupon, class_name: Coupon.to_s, optional: true
  validates_presence_of :expires_at, :amount_paid, :max_txns
  validates :max_txns, numericality: { greater_than: 0 }
  before_create :set_coupon_info
  after_create :update_coupon_counters
  after_create_commit :send_success_email
  after_create_commit :send_email_to_affiliate
  attr_accessor :credits_used

  def amount_paid_in_cents=(cents)
    self.amount_paid = (cents.to_d / 100)
  end

  def amount_paid_in_cents
    (amount_paid * 100).to_i
  end

  private

  def set_coupon_info
    self.commission_coupon = user.referring_coupon
    self.discount_coupon = Coupon.best_of(user, user.referring_coupon, user.discount_coupon)
    self.commission_total = commission_coupon&.calculate_commission(user, amount_paid) || 0
    self.discount_total = plan.price - amount_paid - (credits_used || 0)
  end

  def update_coupon_counters
    commission_coupon&.update_usage!
    discount_coupon&.update_usage!
  end

  def send_success_email
    # UserMailer.with(sub: self, user: user).subscription_created.deliver_later
  end

  def send_email_to_affiliate
    return unless commission_coupon&.owner && commission_total > 0
    if commission_coupon.is_a?(AffiliateCoupon)
      # UserMailer.with(sub: self, user: commission_coupon.owner).affiliate_conversion.deliver_later
    else
      # UserMailer.with(sub: self, user: commission_coupon.owner).refer_friend_conversion.deliver_later
    end
  end
end
