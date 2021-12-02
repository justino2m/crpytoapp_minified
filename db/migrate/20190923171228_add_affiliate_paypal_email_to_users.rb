class AddAffiliatePaypalEmailToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :affiliate_paypal_email, :string
  end
end
