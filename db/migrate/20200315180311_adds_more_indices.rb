class AddsMoreIndices < ActiveRecord::Migration[5.2]
  def change
    remove_index :investments, :date
    add_index :snapshots, [:user_id, :id]
    add_index :investments, [:user_id, :date]
  end
end
