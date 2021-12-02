class AddMetadataToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :metadata, :jsonb
  end
end
