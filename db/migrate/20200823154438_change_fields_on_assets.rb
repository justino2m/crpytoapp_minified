class ChangeFieldsOnAssets < ActiveRecord::Migration[5.2]
  def change
    rename_column :assets, :fee_amount, :total_reported_amount
    remove_column :assets, :stats
  end
end
