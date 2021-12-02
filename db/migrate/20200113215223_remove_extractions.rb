class RemoveExtractions < ActiveRecord::Migration[5.2]
  def change
    drop_table :extractions
  end
end
