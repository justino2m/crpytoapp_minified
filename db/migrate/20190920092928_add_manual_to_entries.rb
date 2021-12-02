class AddManualToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :manual, :boolean, null: false, default: false
  end
end
