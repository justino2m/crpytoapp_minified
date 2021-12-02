class AddRelatedByIdToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :related_by_id, :integer
  end
end
