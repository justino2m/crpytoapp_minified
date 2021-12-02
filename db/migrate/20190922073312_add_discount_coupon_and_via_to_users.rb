class AddDiscountCouponAndViaToUsers < ActiveRecord::Migration[5.2]
  def change
    add_reference :users, :discount_coupon, foreign_key: { to_table: :coupons }
    rename_column :users, :referred_by, :via
  end
end
