module TxnBuilder
  class Transfer < Base
    validates_presence_of :from_amount, :from_currency, :to_amount, :to_currency
    validates :from_amount, numericality: { greater_than: 0 }
    validates :to_amount, numericality: { greater_than: 0 }
    validate :ensure_to_amount_is_less_than_from_amount
    validate :ensure_to_wallet_valid
    validate :ensure_currencies_are_same

    # NOTE: both from_amount and to_amount must be supplied, the difference is set as fee
    def initialize(user, wallet, params, adapter = nil)
      super

      if from_amount > to_amount
        self.fee_amount = from_amount - to_amount
        self.from_amount = to_amount
      end

      if fee_amount > 0
        self.fee_currency = from_currency
        self.fee_account = from_account
      end

      self.to_currency ||= from_currency
      self.to_account ||= fetch_account(to_currency, params[:to_wallet])
      self.label = nil
    end

    def create!
      return if duplicate?

      create_transaction(
        type: Transaction::TRANSFER,
        from_entry: from_entry,
        to_entry: to_entry,
        fee_entry: fee_entry
      )
    end

    private

    def duplicate?
      return false if allow_duplicates
      if external_id
        q = { account_id: [from_account.id, to_account.id], external_id: external_id }
        return pending_entry?(q) || current_user.entries.not_deleted.where(q).exists?
      elsif !allow_txhash_conflicts && txhash
        q = { account_id: [from_account.id, to_account.id], txhash: txhash }
        return pending_entry?(q) || current_user.entries.not_deleted.where(q).exists?
      end

      loose_duplicate?(from_entry) && loose_duplicate?(to_entry)
    end

    def ensure_to_amount_is_less_than_from_amount
      if to_amount.to_d > from_amount.to_d
        errors.add(:to_amount, 'must be less than From amount')
      end
    end

    def ensure_to_wallet_valid
      if options[:to_wallet].nil?
        errors.add(:to_wallet_id, 'cant be blank')
      elsif options[:to_wallet].id == current_wallet.id
        errors.add(:to_wallet_id, 'should not be same as From wallet')
      end
    end

    def ensure_currencies_are_same
      return unless from_currency && to_currency
      if from_currency != to_currency
        self.errors.add(:from_currency_id, 'should be same as To currency')
      end
    end
  end
end
