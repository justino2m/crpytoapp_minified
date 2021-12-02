class AddSpamToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :spam, :boolean, default: false, null: false
  end
end
