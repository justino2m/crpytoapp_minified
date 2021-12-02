class AddFraudDateToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :fraud_date, :datetime
    remove_column :users, :fraud
  end
end
