class AddContractsToCurrencies < ActiveRecord::Migration[5.2]
  def change
    add_column :currencies, :contract_address, :string
    add_column :currencies, :parent_id, :integer
    add_column :currencies, :added_by_user, :boolean, default: false, null: false
  end
end
