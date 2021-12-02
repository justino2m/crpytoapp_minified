class UpdatesPricesMay24th < ActiveRecord::Migration[5.2]
  def up
    # [
    #   { name: 'Hodler', price: 49, max_txns: 100 },
    #   { name: 'Trader', price: 99, max_txns: 1000 },
    #   { name: 'Oracle', price: 279, max_txns: 10_000 },
    # ].each do |attrs|
    #   plan = Plan.where(name: attrs[:name]).first_or_initialize
    #   plan.assign_attributes(attrs)
    #   plan.save!
    # end
  end
end
