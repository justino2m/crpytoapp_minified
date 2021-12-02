class RenameApiRelatedFieldsInWalletServices < ActiveRecord::Migration[5.2]
  def change
    add_column :wallet_services, :integration_type, :string, null: false, default: 'other'
    rename_column :wallet_services, :importer, :api_importer
    rename_column :wallet_services, :csv_only, :api_beta
    rename_column :wallet_services, :active, :api_active
    remove_column :wallet_services, :currency_id
    add_column :wallet_services, :tag, :string
    WalletService.all.each do |int|
      if int.api_importer == 'AltcoinImporter'
        options = JSON.parse(int.options).symbolize_keys
        int.update_attributes!(tag: options[:blockchain], api_importer: options[:blockchain].capitalize + 'Importer')
      else
        int.tag = int.api_importer_klass.tag
        int.save! if int.changed?
      end
    end
    change_column :wallet_services, :tag, :string, null: false, unique: true
    remove_column :wallet_services, :options
  end
end
