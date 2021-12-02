class AddDecimalPriceToPlans < ActiveRecord::Migration[5.2]
  def change
    add_column :plans, :price, :decimal, precision: 8, scale: 2
    Plan.all.map{ |plan| plan.update_attributes!(price: (plan.price_cents.to_d / 100.0).round(2))}
    change_column :plans, :price, :decimal, null: false
    remove_column :plans, :price_cents
  end
end
