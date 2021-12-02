class AddUtmSourceToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :utm_source, :string
    add_column :users, :utm_medium, :string
  end
end
