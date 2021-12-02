class AddNotesToSubscriptions < ActiveRecord::Migration[5.2]
  def change
    add_column :subscriptions, :notes, :string
  end
end
