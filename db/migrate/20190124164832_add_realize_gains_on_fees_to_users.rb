class AddRealizeGainsOnFeesToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :realize_gains_on_fees, :boolean, default: false, null: false
  end
end
