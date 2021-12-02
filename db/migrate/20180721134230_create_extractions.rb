class CreateExtractions < ActiveRecord::Migration[5.2]
  def change
    create_table :extractions do |t|
      t.references :from_investment, foreign_key: { to_table: :investments }, null: true
      t.references :to_investment, foreign_key: { to_table: :investments }, null: false
      t.decimal :amount, null: false, precision: 25, scale: 10
      t.decimal :value, null: false, precision: 25, scale: 10

      t.timestamps
    end
  end
end
