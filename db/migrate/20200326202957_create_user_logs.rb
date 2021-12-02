class CreateUserLogs < ActiveRecord::Migration[5.2]
  def change
    create_table :user_logs do |t|
      t.references :user, foreign_key: true, null: false
      t.string :message, null: false
      t.jsonb :metadata

      t.timestamps
    end
  end
end
