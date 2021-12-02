class CreateCsvMappers < ActiveRecord::Migration[5.2]
  def change
    create_table :csv_mappers do |t|
      t.string :name, null: false
      t.string :type, null: true
      t.text :notes
      t.jsonb :options
      t.jsonb :header_mappings
      t.references :created_by, foreign_key: { to_table: :users }
      t.boolean :public, null: false, default: false

      t.timestamps
    end
  end
end
