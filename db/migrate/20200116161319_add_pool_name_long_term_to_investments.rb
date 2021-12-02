class AddPoolNameLongTermToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :pool_name, :string, index: true
    add_column :investments, :long_term, :boolean, default: false, null: false, index: true
  end
end
