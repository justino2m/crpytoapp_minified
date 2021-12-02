class AddSendEmailToReports < ActiveRecord::Migration[5.2]
  def change
    add_column :reports, :send_email, :boolean, default: false, null: false
  end
end
