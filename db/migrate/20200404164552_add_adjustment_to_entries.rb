class AddAdjustmentToEntries < ActiveRecord::Migration[5.2]
  def change
    add_column :entries, :adjustment, :boolean, null: false, default: false
  end
end
