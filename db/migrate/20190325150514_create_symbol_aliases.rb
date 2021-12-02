class CreateSymbolAliases < ActiveRecord::Migration[5.2]
  def change
    create_table :symbol_aliases do |t|
      t.references :currency, foreign_key: true
      t.string :symbol, null: false
      t.string :tag, null: false

      t.timestamps
    end

    add_index :symbol_aliases, [:symbol, :tag], unique: true
  end
end
