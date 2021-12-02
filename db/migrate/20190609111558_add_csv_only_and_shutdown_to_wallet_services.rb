class AddCsvOnlyAndShutdownToWalletServices < ActiveRecord::Migration[5.2]
  def change
    add_column :wallet_services, :csv_only, :boolean, default: false, null: false
    add_column :wallet_services, :shutdown, :boolean, default: false, null: false
  end
end
