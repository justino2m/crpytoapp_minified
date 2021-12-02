class AddSyncStartedAtToWallets < ActiveRecord::Migration[5.2]
  def change
    add_column :wallets, :sync_started_at, :datetime
  end
end
