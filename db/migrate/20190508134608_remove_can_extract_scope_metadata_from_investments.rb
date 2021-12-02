class RemoveCanExtractScopeMetadataFromInvestments < ActiveRecord::Migration[5.2]
  def change
    remove_column :investments, :can_extract
    remove_column :investments, :scope
    remove_column :investments, :metadata
  end
end
