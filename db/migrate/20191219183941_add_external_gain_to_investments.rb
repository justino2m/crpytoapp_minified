class AddExternalGainToInvestments < ActiveRecord::Migration[5.2]
  def change
    add_column :investments, :external_gain, :boolean, default: false, null: false
    add_index :investments, :external_gain
  end
end
