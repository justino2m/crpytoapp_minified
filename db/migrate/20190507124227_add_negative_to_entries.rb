class AddNegativeToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :negative, :boolean, default: false, null: false
  end
end
