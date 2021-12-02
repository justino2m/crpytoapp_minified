class AddOriginalValueGainToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :original_value, :decimal, precision: 25, scale: 10, default: 0, null: false
    add_column :investments, :original_gain, :decimal, precision: 25, scale: 10, default: 0, null: false
    Investment.update_all('original_value = value, original_gain = gain')
  end
end
