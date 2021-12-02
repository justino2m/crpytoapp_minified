class AddAddedOnDiscontinuedAtToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :added_at, :datetime, null: false
    add_column :currencies, :discontinued_at, :datetime
  end
end
