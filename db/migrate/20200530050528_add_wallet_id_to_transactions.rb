class AddWalletIdToTransactions < ActiveRecord::Migration[5.2]
  def change
    add_column :transactions, :from_wallet_id, :integer
    add_column :transactions, :to_wallet_id, :integer

    say_with_time "Backport transactions.wallet" do
      Wallet.unscoped.find_in_batches(batch_size: 100).with_index do |batch, index|
        say("Processing batch #{index}\r", true)
        batch.each do |wallet|
          account_ids = wallet.accounts.pluck(:id)
          Transaction.unscoped.where(from_account_id: account_ids).where(from_wallet_id: nil).update_all(from_wallet_id: wallet.id)
          Transaction.unscoped.where(to_account_id: account_ids).where(to_wallet_id: nil).update_all(to_wallet_id: wallet.id)
        end
      end
    end
  end
end
