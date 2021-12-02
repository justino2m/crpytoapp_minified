class AddTypeToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :deposit, :boolean
    change_column_default :investments, :deposit, from: nil, to: false
    change_column_null :investments, :deposit, false
  end
end
