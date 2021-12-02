class SnapshotsUpdater
  attr_reader :user, :dates

  # setting lazy will avoid building lots of snapshots and schedule the update job instead
  def initialize(user, dates, lazy)
    @user = user
    @dates = dates.to_a.map{ |dt| dt.to_datetime.end_of_day }.uniq.sort
    @lazy = lazy
    @rates = {}
    @latest = @dates.any?{ |dt| dt > Time.now }
    @dates.reject!{ |x| x > Time.now } # dont want to generate snapshot for today
  end

  def self.call(user, dates, lazy, &block)
    new(user, dates, lazy).process(&block)
  end

  def process
    delete_outdated_snapshots unless @lazy

    snapshots = user.snapshots.where(date: dates.map(&:to_s)).to_a
    missing_dates = (dates.map(&:to_s) - snapshots.map{ |x| x.date.to_datetime.to_s }).map(&:to_datetime)
    # make sure there are transactions on the missing dates
    oldest_date = (user.txns.pluck(Arel.sql('min(date)')).first || Time.now).to_datetime
    missing_dates.reject!{ |dt| dt < oldest_date }
    if missing_dates.any?
      running = UpdateUserStatsWorker.running?(user.id)
      # generate rates only if few missing dates and stats updater is not running
      # for ex. when stats are already up to date and user is logging in every day we can avoid
      # rerunning updater by simply creating a few records here
      if !@lazy || (missing_dates.count < 10 && !running)
        # bulk load rates
        load_rates(currencies.reject{ |x| x.stablecoin? || x == Currency.usd }.map(&:id), missing_dates)
        new_snapshots = missing_dates.map do |date|
          yield if block_given?
          populate_snapshot(user.snapshots.build(date: date))
        end.compact
        Snapshot.import(new_snapshots, on_duplicate_key_ignore: true)
        snapshots.concat(new_snapshots)
      elsif !running
        UpdateUserStatsWorker.perform_later(user.id)
      end
    end

    # add current snapshot
    if @latest
      snapshots.push(populate_snapshot(user.snapshots.build(date: Time.now.end_of_day), true))
    end

    snapshots.compact.sort_by(&:date)
  end

  def delete_outdated_snapshots
    last_snapshot = user.snapshots.last
    if last_snapshot
      # find the earliest entry date that was modified after the last snapshot
      last_change = user.investments
        .where('updated_at >= ?', last_snapshot.updated_at)
        .pluck(Arel.sql('min(date)'))
        .first

      # delete snapshots if such an investment exists
      user.snapshots.where('date >= ?', last_change).delete_all if last_change
    end
  end

  def currencies
    @currencies ||= begin
      arr = Currency.where(id: user.accounts.distinct.pluck(:currency_id)).to_a
      arr.push(user.base_currency)
      arr.uniq
    end
  end

  def populate_snapshot(snapshot, use_live_rates=false)
    investments = user.investments.where('date <= ?', snapshot.date)
    if use_live_rates
      snapshot.total_worth = user.total_crypto_worth
    else
      totals = investments.group(:currency_id).sum(:amount)
      return nil unless totals.present?
      snapshot.total_worth = totals.sum do |currency_id, total_amount|
        from_currency = currencies.find{ |x| x.id == currency_id }
        if total_amount > 0
          rate = get_rate(from_currency, user.base_currency, snapshot.date)
        else
          rate = 0
        end
        (total_amount * rate).round(8)
      end
    end
    snapshot.invested = investments.deposits.sum(:value) - investments.withdrawals.sum(:value)
    snapshot.gains = investments.withdrawals.sum(:gain)
    snapshot
  end

  def load_rates(currency_ids, dates)
    from = dates.first.beginning_of_day
    to = dates.last.end_of_day

    rates = Rate
      .where(currency_id: currency_ids)
      .where('date >= ?', from)
      .where('date <= ?', to)
      .select("currency_id, date_trunc('day', date) date, max(quoted_rate) rate")
      .group('1, 2')
      .as_json
      .inject({}) do |memo, data|
        memo[data['currency_id']] ||= {}
        memo[data['currency_id']][data['date'].to_date] = data['rate']
        memo
      end

    missing_initial_rates = rates.select{ |_, dts| dts[from.to_date].nil? }.keys
    missing_initial_rates.concat(currency_ids - rates.keys)
    if missing_initial_rates.any?
      initial_rates = Rate
        .where(currency_id: missing_initial_rates)
        .where('date < ?', from)
        .order(currency_id: :asc, date: :desc)
        .select('DISTINCT ON (currency_id) rates.currency_id, rates.date, rates.quoted_rate as rate')
        .as_json

      initial_rates.each do |initial|
        rates[initial['currency_id']] ||= {}
        rates[initial['currency_id']][initial['date'].to_date] = initial['rate']
      end
    end

    # only keep the rates that belong to our dates
    currency_ids.each do |cid|
      next unless rates[cid]
      available_dates = rates[cid].keys.sort.reverse # desc 2018...2010
      next unless available_dates.any?
      dates.each do |dt|
        best_date = available_dates.find{ |avdt| avdt <= dt }
        next unless best_date
        set_rate(cid, dt, rates[cid][best_date])
      end
    end
  end

  def get_rate(from_currency, to_currency, date)
    return 0 if from_currency.nil? || to_currency.nil?
    from_currency = from_currency.stablecoin if from_currency.stablecoin?
    to_currency = to_currency.stablecoin if to_currency.stablecoin?
    return 1 if from_currency == to_currency

    if from_currency == Currency.usd
      rate = @rates[to_currency.id].try(:dig, date.to_date) || 0
      return 0 if rate.zero?
      1 / rate
    elsif to_currency == Currency.usd
      @rates[from_currency.id].try(:dig, date.to_date) || 0
    else
      get_rate(from_currency, Currency.usd, date) * get_rate(Currency.usd, to_currency, date)
    end
  end

  def set_rate(currency_id, date, rate)
    @rates[currency_id] ||= {}
    @rates[currency_id][date.end_of_day.to_date] = rate
  end
end
