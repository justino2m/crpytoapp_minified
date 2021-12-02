class AddsUserIdToExtractions < ActiveRecord::Migration[5.2]
  def change
    add_reference :extractions, :user, foreign_key: true
  end
end
