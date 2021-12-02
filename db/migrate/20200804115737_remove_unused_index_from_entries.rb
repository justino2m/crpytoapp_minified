class RemoveUnusedIndexFromEntries < ActiveRecord::Migration[5.2]
  def change
    remove_index :entries, :external_id
  end
end
