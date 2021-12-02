class CreateCountries < ActiveRecord::Migration[5.2]
  def change
    create_table :countries do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.references :currency, foreign_key: true, null: false
      t.jsonb :metadata

      t.timestamps
    end
  end
end
