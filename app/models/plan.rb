class Plan < ApplicationRecord
  has_many :subscriptions

  def final_price(user)
    return price unless user
    coupon = Coupon.best_of(user, user.referring_coupon, user.discount_coupon)
    return coupon.calculate_discounted_price(user, price) if coupon
    price
  end

  def price_in_cents
    (price * 100).to_i
  end

  def final_price_in_cents(user)
    (final_price(user) * 100).to_i
  end
end
