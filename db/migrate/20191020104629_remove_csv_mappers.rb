class RemoveCsvMappers < ActiveRecord::Migration[5.2]
  def change
    remove_column :csv_imports, :csv_mapper_id
    drop_table :csv_mappers
  end
end
