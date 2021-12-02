class AddMappingIdToCsvImports < ActiveRecord::Migration[5.2]
  def change
    add_column :csv_imports, :mapping_id, :string
  end
end
