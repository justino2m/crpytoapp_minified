class AddCryptoCompareIdToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :crypto_compare_id, :string
  end
end
