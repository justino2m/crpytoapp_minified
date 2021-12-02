class RemoveOptionsFromReports < ActiveRecord::Migration[5.2]
  def change
    remove_column :reports, :options
    add_column :reports, :year, :integer
  end
end
