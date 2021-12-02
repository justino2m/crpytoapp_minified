class AddExtractedValueToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :extracted_value, :decimal, default: 0, null: false, precision: 25, scale: 10
  end
end
