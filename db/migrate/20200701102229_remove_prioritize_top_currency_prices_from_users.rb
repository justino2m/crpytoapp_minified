class RemovePrioritizeTopCurrencyPricesFromUsers < ActiveRecord::Migration[5.2]
  def change
    # User.preferences_where(prioritize_top_currency_prices: true).each do |user|
    #   user.update_attributes!(pricing_strategy: User::PREFER_TOP_50)
    # end
  end
end
