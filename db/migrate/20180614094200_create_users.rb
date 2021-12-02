class CreateUsers < ActiveRecord::Migration[5.2]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.attachment :avatar
      t.references :base_currency, foreign_key: { to_table: :currencies }, null: false
      t.references :display_currency, foreign_key: { to_table: :currencies }, null: false
      t.boolean :account_based_cost_basis, default: false
      t.boolean :realize_gains_on_exchange, default: false
      t.string :password_digest
      t.string :password_reset_token
      t.string :api_token
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
