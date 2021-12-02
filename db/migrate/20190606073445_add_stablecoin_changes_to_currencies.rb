class AddStablecoinChangesToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :stablecoin_id, :integer
    rename_column :currencies, :parent_id, :platform_id
    rename_column :currencies, :contract_address, :token_address
    # Currency.where(stablecoin: true).map do |x|
    #   x.stablecoin_id = x.platform_id
    #   x.platform = x.token_address.present? ? Currency.crypto.prioritized.find_by(symbol: x.metadata['platform']['symbol']) : nil
    #   x.save!
    # end
    remove_column :currencies, :stablecoin
  end
end
