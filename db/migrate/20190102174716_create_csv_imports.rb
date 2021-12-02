class CreateCsvImports < ActiveRecord::Migration[5.2]
  def change
    create_table :csv_imports do |t|
      t.references :user, foreign_key: true, null: false
      t.references :csv_mapper, foreign_key: true
      t.integer :wallet_id, null: false # we can delete a wallet without deleting the csv
      t.attachment :file
      t.text :initial_rows
      t.jsonb :results
      t.jsonb :options
      t.datetime :completed_at

      t.timestamps
    end
  end
end
