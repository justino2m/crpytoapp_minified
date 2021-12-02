class CreateRawReports < ActiveRecord::Migration[5.2]
  def change
    create_table :raw_reports do |t|
      t.references :report, foreign_key: true, null: false
      t.string :format, null: false
      t.attachment :file

      t.timestamps
    end
  end
end
