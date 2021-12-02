class AddCurrencyToWalletServices < ActiveRecord::Migration[5.2]
  def change
    add_reference :wallet_services, :currency, foreign_key: true
  end
end
