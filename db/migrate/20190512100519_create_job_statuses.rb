class CreateJobStatuses < ActiveRecord::Migration[5.2]
  def change
    create_table :job_statuses do |t|
      t.references :user, foreign_key: true, null: false
      t.string :klass, null: false
      t.string :status, null: false
      t.string :jid, null: false
      t.text :args
      t.timestamps
    end
    add_index :job_statuses, [:jid, :klass, :user_id], unique: true
  end
end
