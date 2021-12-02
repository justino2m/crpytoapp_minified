class AddManualAndMissingRatesToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :manual, :boolean, null: false, default: false
    add_column :transactions, :missing_rates, :boolean, null: false, default: false
  end
end
