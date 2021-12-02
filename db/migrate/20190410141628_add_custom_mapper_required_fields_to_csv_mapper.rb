class AddCustomMapperRequiredFieldsToCsvMapper < ActiveRecord::Migration[5.2]
  def change
    add_column :csv_mappers, :custom_mapper, :string
    add_column :csv_mappers, :required_headers, :string, array: true, null: false
    add_column :csv_mappers, :optional_headers, :string, array: true
    add_column :csv_mappers, :row_defaults, :jsonb
  end
end
