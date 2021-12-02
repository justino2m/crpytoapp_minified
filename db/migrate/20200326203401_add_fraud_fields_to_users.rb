class AddFraudFieldsToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :fraud, :boolean, null: false, default: false
    add_column :users, :related_to_id, :integer
  end
end
