class AddExtractionFieldsToInvestments < ActiveRecord::Migration[5.2]
  def change
    remove_column :investments, :fee
    remove_column :investments, :extraction_failed
    remove_column :investments, :external_gain
    remove_column :investments, :original_gain
    remove_column :investments, :original_value
    add_column :investments, :subtype, :string, index: true
    add_column :investments, :from_date, :datetime
    add_reference :investments, :from, foreign_key: { to_table: :investments }
  end
end
