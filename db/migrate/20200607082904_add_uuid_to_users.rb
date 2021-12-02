class AddUuidToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :uuid, :string
    User.find_each do |user|
      user.update_columns(uuid: SecureRandom.uuid)
    end
    change_column :users, :uuid, :string, null: false
    add_index :users, :uuid, unique: true
  end
end
