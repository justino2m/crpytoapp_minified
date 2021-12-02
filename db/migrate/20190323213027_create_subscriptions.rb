class CreateSubscriptions < ActiveRecord::Migration[5.2]
  def change
    create_table :subscriptions do |t|
      t.references :user, foreign_key: true, null: false
      t.references :plan, foreign_key: true, null: false
      t.datetime :expires_at, null: false
      t.datetime :refunded_at
      t.string :stripe_charge_id
      t.integer :amount_paid_cents, null: false

      t.timestamps
    end
  end
end
