class AddLastErrorToWallets < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :last_error, :string
    add_column :wallets, :last_error_at, :datetime
  end
end
