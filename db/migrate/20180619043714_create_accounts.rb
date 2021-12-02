class CreateAccounts < ActiveRecord::Migration[5.2]
  def change
    create_table :accounts do |t|
      t.references :user, foreign_key: true, null: false
      t.references :wallet, foreign_key: true, null: true # can be null when wallet is destroyed
      t.references :currency, foreign_key: true, null: false
      t.decimal :balance, null: false, default: 0, precision: 25, scale: 10
      t.decimal :fees, null: false, default: 0, precision: 25, scale: 10
      t.string :external_id
      t.jsonb :external_data

      t.timestamps
    end
  end
end
