class CreateWalletServices < ActiveRecord::Migration[5.2]
  def change
    create_table :wallet_services do |t|
      t.string :name, null: false
      t.string :type, null: false
      t.attachment :icon
      t.boolean :editable_wallets, default: false
      t.boolean :exchange, default: true
      t.boolean :active, default: true
      t.string :external_id
      t.jsonb :external_data

      t.timestamps
    end
  end
end
