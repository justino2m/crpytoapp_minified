class CreateWallets < ActiveRecord::Migration[5.2]
  def change
    create_table :wallets do |t|
      t.references :user, foreign_key: true, null: false
      t.references :wallet_service, foreign_key: true # nullable
      t.string :name, null: false
      t.boolean :editable, default: true
      t.datetime :synced_at
      t.jsonb :metadata
      t.jsonb :syncdata

      t.timestamps
    end
  end
end
