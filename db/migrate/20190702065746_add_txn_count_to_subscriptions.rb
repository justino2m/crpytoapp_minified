class AddTxnCountToSubscriptions < ActiveRecord::Migration[5.2]
  def change
    add_column :subscriptions, :max_txns, :integer, default: 0, null: false
    Subscription.where(nil).each { |x| x.update_attributes!(max_txns: x.plan.max_txns) }
  end
end
