class AddStateToCsvImports < ActiveRecord::Migration[5.2]
  def change
    add_column :csv_imports, :state, :string
    add_column :csv_imports, :error, :string
  end
end
