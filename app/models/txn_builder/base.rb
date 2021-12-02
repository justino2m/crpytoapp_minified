module TxnBuilder
  class Base
    include ActiveModel::Validations
    validate :ensure_amounts_are_within_bounds
    validate :ensure_date_is_valid

    ALL_ATTRIBUTES = [
      :date, :description, :label,
      :from_amount, :from_currency,
      :to_amount, :to_currency,
      :fee_amount, :fee_currency,
      :net_worth_amount, :net_worth_currency,
      :fee_worth_amount, :fee_worth_currency,
      :txhash, :txsrc, :txdest,
      :external_id, :external_data,
      :from_currency_id, :to_currency_id,
      :fee_currency_id, :net_worth_currency_id,
      :fee_worth_currency_id, :importer_tag,
      :synced, :manual, :margin,
      :group_name
    ].freeze

    # child classes may have their own options ex. Transfer has the to_wallet option
    BASE_OPTIONS = [
      :preferred_currency_ids,
      :default_timezone
    ].freeze

    attr_accessor :current_user, :current_wallet, :adapter, :options
    attr_accessor :from_account, :to_account, :fee_account, :allow_duplicates, :allow_txhash_conflicts, :prevent_same_run_conflicts
    attr_accessor *ALL_ATTRIBUTES

    delegate :pending_entry?, :pending_txn?, :find_pending_entry, :find_pending_txn, to: :adapter

    def initialize(user, wallet, params, adapter = nil)
      self.current_user = user
      self.current_wallet = wallet
      self.adapter = adapter || TxnBuilder::Adapter.new(user, wallet, false)
      self.options = params.except(*ALL_ATTRIBUTES)

      # this is only used for adding temporary txns via Editor
      self.allow_duplicates = params[:allow_duplicates].to_boolean

      # setting this to true will exclude txhash from duplicate checks (false by default)
      self.allow_txhash_conflicts = params[:allow_txhash_conflicts].to_boolean

      # setting this to true will prevent the same adapter from adding similar-looking txns (false by default)
      # only needs to be enabled if an importer can return the same txns multiple times in the same run
      self.prevent_same_run_conflicts = params[:prevent_same_run_conflicts].to_boolean

      self.importer_tag = params[:importer_tag] # must be before fetch_currency!
      self.synced = !!nil_if_blank(params[:synced])
      self.manual = !!nil_if_blank(params[:manual])
      self.margin = !!nil_if_blank(params[:margin])
      self.description = nil_if_blank(params[:description].to_s)
      self.label = nil_if_blank(params[:label].to_s)&.downcase
      self.group_name = nil_if_blank(params[:group_name].to_s)

      self.date = TxnBuilder::Helper.normalize_date(params[:date], options[:default_timezone])
      self.from_amount = TxnBuilder::Helper.normalize_amount(params[:from_amount])
      self.from_currency = fetch_currency(params[:from_currency], params[:from_currency_id])
      self.from_account = fetch_account(from_currency)
      self.to_amount = TxnBuilder::Helper.normalize_amount(params[:to_amount])
      self.to_currency = fetch_currency(params[:to_currency], params[:to_currency_id])
      self.to_account = fetch_account(to_currency, params[:to_wallet])
      self.fee_amount = TxnBuilder::Helper.normalize_amount(params[:fee_amount])
      self.fee_currency = fetch_currency(params[:fee_currency], params[:fee_currency_id]) if fee_amount > 0
      self.fee_account = fetch_account(fee_currency) if fee_amount > 0
      self.net_worth_amount = TxnBuilder::Helper.normalize_amount(params[:net_worth_amount])
      self.net_worth_currency = fetch_currency(params[:net_worth_currency], params[:net_worth_currency_id])
      self.fee_worth_amount = TxnBuilder::Helper.normalize_amount(params[:fee_worth_amount])
      self.fee_worth_currency = fetch_currency(params[:fee_worth_currency], params[:fee_worth_currency_id])

      self.txhash = TxnBuilder::Helper.normalize_hash(params[:txhash].to_s)
      self.txsrc = nil_if_blank(params[:txsrc].to_s)
      self.txdest = nil_if_blank(params[:txdest].to_s)
      self.external_data = params[:external_data]
      self.external_id = nil_if_blank(params[:external_id].to_s)
    end

    def self.create!(user, wallet, params, adapter = nil)
      builder = self.new(user, wallet, params, adapter)
      if builder.valid?
        builder.create!
      else
        raise TxnBuilder::Error.new(builder)
      end
    end

    def create!
      raise 'must be implemented'
    end

    private

    def from_entry
      return nil unless from_amount && from_currency && from_account
      {
        date: date,
        account: from_account,
        amount: -from_amount,
        synced: synced,
        manual: manual,
        txhash: txhash,
        external_id: external_id,
        external_data: external_data,
        importer_tag: importer_tag,
      }
    end

    def to_entry
      return nil unless to_amount && to_currency && to_account
      {
        date: date,
        account: to_account,
        amount: to_amount,
        synced: synced,
        manual: manual,
        txhash: txhash,
        external_id: external_id,
        external_data: external_data,
        importer_tag: importer_tag,
      }
    end

    def fee_entry
      return nil unless fee_currency && fee_account && fee_amount > 0
      {
        date: date,
        fee: true,
        account: fee_account,
        amount: -fee_amount,
        synced: synced,
        manual: manual,
        txhash: txhash,
        external_id: external_id,
        external_data: external_data,
        importer_tag: importer_tag,
      }
    end

    def ensure_amounts_are_within_bounds
      if from_amount && from_amount.to_d.abs > 10**15
        errors.add(:from_amount, 'must be less than 10^15')
      elsif to_amount && to_amount.to_d.abs > 10**15
        errors.add(:to_amount, 'must be less than 10^15')
      elsif fee_amount && fee_amount.to_d.abs > 10**15
        errors.add(:fee_amount, 'must be less than 10^15')
      end
    end

    def ensure_date_is_valid
      if date.nil?
        errors.add(:date, 'is invalid')
      elsif date > 1.year.from_now || date.year < 2010
        errors.add(:date, 'is out of bounds/invalid')
      end
    end

    def nil_if_blank(s)
      return s unless s.is_a?(String)
      s = s.strip
      s.blank? ? nil : s
    end

    # the entries must be explicitly passed into this method to avoid creating entries accidentally
    def create_transaction(
      type:,
      from_entry: nil,
      to_entry: nil,
      fee_entry: nil,
      group_name: nil,
      group_date: nil,
      group_from: nil,
      group_to: nil,
      group_count: nil
    )
      adapter.create_transaction(
        type: type,
        date: date,
        label: label,
        description: description,
        from_entry: from_entry,
        to_entry: to_entry,
        fee_entry: fee_entry,
        net_worth_amount: net_worth_amount,
        net_worth_currency: net_worth_currency,
        fee_worth_amount: fee_worth_amount,
        fee_worth_currency: fee_worth_currency,
        txhash: txhash,
        txsrc: txsrc,
        txdest: txdest,
        importer_tag: importer_tag,
        margin: margin,
        group_name: group_name,
        group_date: group_date,
        group_from: group_from,
        group_to: group_to,
        group_count: group_count
      )
    end

    def fetch_account(currency, wallet = nil)
      return unless currency
      adapter.fetch_account(currency, wallet || current_wallet)
    end

    def fetch_currency(symbol, id = nil)
      return if symbol.blank? && id.blank?
      return symbol if symbol.is_a? Currency
      id = symbol if symbol.is_a?(Integer)
      adapter.fetch_currency(importer_tag, symbol: symbol, id: id, preferred_ids: options[:preferred_currency_ids], raise: true)
    end

    def create_or_merge_grouped_txn(
      type:,
      from_entry: nil,
      to_entry: nil
    )
      q = {
        type: type,
        group_name: group_name,
        group_date: date.utc.beginning_of_day
      }

      q.merge!(to_account: to_entry[:account]) if to_entry
      q.merge!(from_account: from_entry[:account]) if from_entry

      grouped_txn = find_pending_txn(q) || current_user.txns.find_by(q)
      if grouped_txn
        return if grouped_txn.group_from <= date && grouped_txn.group_to >= date && grouped_txn.persisted? && adapter.initialized_at > grouped_txn.created_at
        earliest_date = [grouped_txn.group_from, date].min
        oldest_date = [grouped_txn.group_to, date].max

        entry = grouped_txn.entries.first
        entry.date = to_entry ? earliest_date : oldest_date
        entry.amount += to_entry ? to_entry[:amount] : from_entry[:amount]
        entry.save! if entry.persisted?

        grouped_txn.group_from = earliest_date
        grouped_txn.group_to = oldest_date
        grouped_txn.group_count += 1
        grouped_txn.update_from_entries
        grouped_txn.update_totals
        grouped_txn.save! if grouped_txn.persisted?
        grouped_txn
      else
        create_transaction(
          type: type,
          from_entry: from_entry,
          to_entry: to_entry,
          group_name: group_name,
          group_date: date.beginning_of_day,
          group_from: date,
          group_to: date,
          group_count: 1
        )
      end
    end

    def loose_duplicate?(entry, txhash = nil)
      q = {
        account_id: entry[:account].id,
        amount: entry[:amount],
      }

      if txhash
        q[:txhash] = txhash
        q[:date] = (entry[:date] - 1.day)..(entry[:date] + 1.day)
      else
        q[:date] = (entry[:date] - 1.minute)..(entry[:date] + 1.minute)
      end

      if prevent_same_run_conflicts
        return pending_entry?(q) || current_user.entries.not_deleted.where(q).exists?
      end

      current_user.entries.not_deleted.where(q).where('created_at < ?', adapter.initialized_at.utc.to_s).exists?
    end
  end
end
