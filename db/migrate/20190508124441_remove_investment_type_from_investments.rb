class RemoveInvestmentTypeFromInvestments < ActiveRecord::Migration[5.2]
  def change
    remove_column :investments, :investment_type
  end
end
