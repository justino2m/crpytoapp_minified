class DropRawReports < ActiveRecord::Migration[5.2]
  def up
    drop_table :raw_reports
  end
end
