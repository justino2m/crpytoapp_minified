class WalletCleanup
  def self.call(user)
    cleanup_orphan_accounts(user)
    update_account_balances(user)
  end

  private

  # TODO: this should not be necessary as we update account balances after adding transactions
  # however, for some reason a lot of accounts contain incorrect balances, need to get to
  # the bottom of this issue and get rid of this method afterwards.
  # this is a temporary measure!
  #
  # Update 11/3/2020 - this bug might have been because of transfer mergers.
  # we were deleting the other txn after the merger which emant that the update_account_totals would
  # also take the txn to be deleted into account causing wrong balance. remove it if we no longer see this error.
  # Update 7/4/2020 - we rely on this when unmerging transfers during wallet/account deletion
  def self.update_account_balances(user)
    updateable_accounts = []
    user.accounts.find_each do |account|
      yield if block_given?

      old_balance = account.balance
      account.update_totals
      if account.balance != old_balance
        Rollbar.warning(
          "account balance does not match",
          user: user.email,
          wallet: account.wallet&.name,
          txns_in_account: account.txns.count,
          total_txns: user.txns.count,
          previous_balance: old_balance.to_s,
          new_balance: account.balance.to_s,
          currency: account.currency.symbol,
          wallet_id: account.wallet_id,
        )
        updateable_accounts << account
      end
    end

    Account.import(updateable_accounts, on_duplicate_key_update: [:balance, :fees], validate: false) if updateable_accounts.any?
  end

  # This method unmerges cross-wallet transactions and removes accounts for deleted wallets
  def self.cleanup_orphan_accounts(user)
    user.accounts.where(wallet: nil).find_each(&:destroy!)
    # txns have to be deleted after all accounts are gone
    txns = user.txns.pending_deletion
    user.investments.where(transaction_id: txns.select(:id)).update_all(transaction_id: nil) # only nullify so calculator can delete them later
    txns.delete_all
  end
end
