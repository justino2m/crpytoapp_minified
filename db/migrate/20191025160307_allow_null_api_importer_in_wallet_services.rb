class AllowNullApiImporterInWalletServices < ActiveRecord::Migration[5.2]
  def change
    change_column :wallet_services, :api_importer, :string, null: true
    change_column :wallet_services, :api_active, :boolean, null: false
    remove_column :wallet_services, :exchange
  end
end
