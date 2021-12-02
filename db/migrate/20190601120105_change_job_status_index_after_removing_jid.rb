class ChangeJobStatusIndexAfterRemovingJid < ActiveRecord::Migration[5.2]
  def change
    JobStatus.delete_all
    remove_index :job_statuses, [:jid, :klass, :user_id]
    remove_column :job_statuses, :jid
    remove_column :job_statuses, :args
    add_column :job_statuses, :args, :string, default: '', null: false
    add_index :job_statuses, [:user_id, :klass, :args], unique: true
  end
end
