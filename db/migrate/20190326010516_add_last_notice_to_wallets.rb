class AddLastNoticeToWallets < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :last_notice, :text
  end
end
