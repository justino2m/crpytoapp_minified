class AddCouponFieldsToSubscriptions < ActiveRecord::Migration[5.2]
  def change
    add_reference :subscriptions, :commission_coupon, foreign_key: { to_table: :coupons }
    add_reference :subscriptions, :discount_coupon, foreign_key: { to_table: :coupons }
    add_column :subscriptions, :commission_total, :decimal, precision: 8, scale: 2, default: 0, null: false
    add_column :subscriptions, :discount_total, :decimal, precision: 8, scale: 2, default: 0, null: false
    add_column :subscriptions, :amount_paid, :decimal, precision: 8, scale: 2
    Subscription.all.map{ |sub| sub.update_attributes!(amount_paid: (sub.amount_paid_cents.to_d / 100.0).round(2))}
    change_column :subscriptions, :amount_paid, :decimal, null: false
    remove_column :subscriptions, :amount_paid_cents
  end
end
