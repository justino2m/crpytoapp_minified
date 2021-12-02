class AllowNullingWalletIdInCsvImports < ActiveRecord::Migration[5.2]
  def change
    change_column :csv_imports, :wallet_id, :integer, null: true
  end
end
