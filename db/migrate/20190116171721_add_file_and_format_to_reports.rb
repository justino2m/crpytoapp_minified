class AddFileAndFormatToReports < ActiveRecord::Migration[5.2]
  def change
    Report.delete_all
    add_attachment :reports, :file
    add_column :reports, :format, :string, null: false
  end
end
