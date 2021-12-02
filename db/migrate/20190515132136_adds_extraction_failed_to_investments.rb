class AddsExtractionFailedToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :extraction_failed, :boolean, default: false
  end
end
