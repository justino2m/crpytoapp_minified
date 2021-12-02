module TxnBuilder
  class Editor
    attr_accessor :current_user, :txn

    TYPES = [
      DEPOSIT = 'deposit',
      WITHDRAWAL = 'withdrawal',
      TRADE = 'trade',
      TRANSFER = 'transfer'
    ]

    # these dont require changes to the entries
    SIMPLE_ATTRIBUTES = [
      :txhash,
      :txsrc,
      :txdest,
      :description,
      :net_worth_amount,
      :net_worth_currency_id,
      :fee_worth_amount,
      :fee_worth_currency_id,
      :label,
    ]

    ATTRIBUTES = [
      :type,
      :date,
      :from_amount,
      :from_currency_id,
      :to_amount,
      :to_currency_id,
      :fee_amount,
      :fee_currency_id,
      :from_wallet_id,
      :to_wallet_id
    ] + SIMPLE_ATTRIBUTES

    def initialize(user, txn = nil)
      self.current_user = user
      self.txn = txn
    end

    def create!(attrs)
      attrs = attrs.to_h.symbolize_keys
      create_txn_internal(current_user, attrs)
    end

    def update!(attrs)
      attrs = attrs.to_h.symbolize_keys
      (attrs.keys - SIMPLE_ATTRIBUTES).empty? ? shallow_update!(attrs) : full_update!(attrs)
    end

    # this only changes the supplied attributes and ignores the rest
    def shallow_update!(attrs)
      txn.assign_attributes(attrs.slice(*SIMPLE_ATTRIBUTES))
      txn.update_totals!
      txn
    end

    def full_update!(attrs)
      from_wallet, to_wallet = fetch_wallets(attrs)
      adapter = TxnBuilder::Adapter.new(current_user, from_wallet || to_wallet, true) # set importing to true to avoid persisting to db

      # we create a fake unpersisted txn so we can compare the attributes easily, this
      # will also raise errors if the updated txn is invalid
      # note: this should create the relevant accounts but should not create/update any txn
      fake_attrs = attrs.merge(allow_duplicates: true)
      SIMPLE_ATTRIBUTES.each { |name| fake_attrs[name] = txn[name] unless fake_attrs.key?(name) }
      fake = create_txn_internal(current_user, fake_attrs, adapter)
      raise "transaction was persisted by editor!!" if fake.persisted?

      date_changed = txn.date != fake.date
      delete_entries = []
      new_entries = []

      if changed?(txn, fake, :from_amount, :from_currency_id, :from_account_id) || (txn.from_currency_id && date_changed && txn.from_source != 'api')
        if txn.from_source == 'api'
          # theres a special case where a synced withdrawal gets converted into transfer (or vice versa),
          # this will cause the from_amount to be different but if the total of from_amount and fee
          # is still same then we can add an adjustment to 'fix' the from_amount without modifying the
          # synced entry.
          from_amount = txn.transfer? ? txn.from_amount + txn.fee_amount : txn.from_amount
          from_amount2 = fake.transfer? ? fake.from_amount + fake.fee_amount : fake.from_amount
          if from_amount != from_amount2 || changed?(txn, fake, :from_currency_id, :from_account_id)
            raise TxnBuilder::Error, "Sent part of the txn cant be modified"
          end
        else
          delete_entries += txn.entries.select { |x| x.account_id == txn.from_account_id && !x.fee? }.map(&:id)
          new_entries += fake.entries.select { |x| x.account_id == fake.from_account_id && !x.fee? }
        end
      end

      if changed?(txn, fake, :to_amount, :to_currency_id, :to_account_id) || (txn.to_currency_id && date_changed && txn.to_source != 'api')
        if txn.to_source == 'api'
          raise TxnBuilder::Error, "Received part of the txn cant be modified"
        else
          delete_entries += txn.entries.select { |x| x.account_id == txn.to_account_id && !x.fee? }.map(&:id)
          new_entries += fake.entries.select { |x| x.account_id == fake.to_account_id && !x.fee? }
        end
      end

      fee_synced = !txn.entries.select(&:fee?).none?(&:synced?) # needs to return false if empty
      if changed?(txn, fake, :type, :fee_amount, :fee_currency_id, :fee_account_id) || (txn.fee_currency_id && date_changed && !fee_synced)
        if fee_synced
          raise TxnBuilder::Error, "Fee part of the txn cant be modified"
        else
          delete_entries += txn.entries.select { |x| x.fee? || x.adjustment? }.map(&:id)
          new_entries += fake.entries.select(&:fee?)
        end
      end

      # try to merge into existing txn if possible
      if fake.transfer? || fake.trade?
        if txn.deposit?
          other = TransferMatcher.find_txn(
            current_user,
            date: fake.date,
            amount: -(fake.transfer? ? fake.from_amount + fake.fee_amount : fake.from_amount),
            currency_id: fake.from_currency_id,
            account_id_eq: fake.from_account_id,
            txhash: fake.txhash,
            max_deviation: 0.0000_0001,
            fiat: txn.fiat_deposit?
          )
        elsif txn.withdrawal?
          other = TransferMatcher.find_txn(
            current_user,
            date: fake.date,
            amount: fake.to_amount,
            currency_id: fake.to_currency_id,
            account_id_eq: fake.to_account_id,
            txhash: fake.txhash,
            max_deviation: 0.0000_0001,
            fiat: txn.fiat_withdrawal?
          )
        end

        if other
          if fake.net_worth_currency_id.nil?
            fake.net_worth_amount = other.net_worth_amount
            fake.net_worth_currency_id = other.net_worth_currency_id
          end

          if fake.fee_worth_currency_id.nil?
            fake.fee_worth_amount = other.fee_worth_amount
            fake.fee_worth_currency_id = other.fee_worth_currency_id
          end

          fake.txsrc = other.txsrc if fake.txsrc.blank?
          fake.txdest = other.txdest if fake.txdest.blank?
          fake.txhash = other.txhash if fake.txhash.blank?
          fake.description = other.description if fake.description.blank?

          # note that this will not give us a fee entry in case of transfers so have to call merge_transfer_entries
          new_entries.reject! { |x| x.account_id == (other.from_account_id || other.to_account_id) }
          new_entries += other.entries.map(&:dup)
        end
      end

      ActiveRecord::Base.transaction do
        txn.assign_attributes(fake.attributes.symbolize_keys.slice(*SIMPLE_ATTRIBUTES + [:cached_rates]))
        Entry.where(id: delete_entries).soft_delete! if delete_entries.any?

        if new_entries.any? || delete_entries.any?
          other.destroy! if other

          if fake.transfer? && (txn.from_source == 'api' || other) # if from part is synced we have to create an adjustment for it
            txn.entries.reload

            # fee will be created by this method
            txn.merge_transfer_entries!(new_entries.reject(&:fee?))
          else
            txn.merge_entries!(new_entries)
          end
        else
          txn.update_totals!
        end
      end

      txn
    end

    private

    def create_txn_internal(current_user, attrs, adapter = nil)
      from_wallet, to_wallet = fetch_wallets(attrs)

      attrs.merge!(manual: true)
      case attrs.delete(:type)
      when DEPOSIT
        TxnBuilder::Deposit.create!(current_user, to_wallet, attrs, adapter)
      when WITHDRAWAL
        TxnBuilder::Withdrawal.create!(current_user, from_wallet, attrs, adapter)
      when TRADE
        TxnBuilder::Trade.create!(current_user, from_wallet, attrs.merge(to_wallet: to_wallet), adapter)
      when TRANSFER
        TxnBuilder::Transfer.create!(current_user, from_wallet, attrs.merge(to_wallet: to_wallet), adapter)
      else
        raise TxnBuilder::Error, "type must be one of: #{TYPES.join(', ')}"
      end
    end

    def fetch_wallets(attrs)
      from_wallet = current_user.wallets.find(attrs[:from_wallet_id]) if attrs[:from_wallet_id].present?
      to_wallet = current_user.wallets.find(attrs[:to_wallet_id]) if attrs[:to_wallet_id].present?
      raise TxnBuilder::Error, "no wallet specified" unless from_wallet || to_wallet
      [from_wallet, to_wallet]
    end

    def changed?(txn1, txn2, *attrs)
      attrs.any? do |attr|
        txn1.send(attr) != txn2.send(attr)
      end
    end
  end
end
