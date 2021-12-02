require 'rails_helper'

RSpec.describe SnapshotsUpdater, type: :model do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet, user: user) }
  let(:wallet2) { create(:wallet, user: user) }
  let(:eth) { create(:currency, symbol: 'ETH') }
  let(:btc) { create(:currency, symbol: 'BTC') }
  let(:dates) { (Date.parse('2017-12-25')..Date.parse('2018-01-31')).to_a }

  before do
    [
      [btc, '2017-10-01', 9],
      [btc, '2017-10-05', 5],
      [btc, '2018-01-04', 10],
      [btc, '2018-01-11', 15],
      [btc, '2018-01-17', 1],

      [eth, '2017-10-02', 90],
      [eth, '2017-10-08', 50],
      [eth, '2017-10-15', 35],
      [eth, '2018-01-04', 100],
      [eth, '2018-01-18', 150],
      [eth, '2018-01-26', 10],
    ].each { |x| Rate.create!(currency: x[0], date: x[1], quoted_rate: x[2]) }

    deposit('2018-01-01', '1 BTC', '10 USD')
    deposit('2018-01-01', '1 ETH', '10 USD')

    deposit('2018-01-05', '5 BTC', '500 USD')
    deposit('2018-01-05', '5 ETH', '500 USD')

    deposit('2018-01-10', '10 BTC', '10000 USD')
    deposit('2018-01-10', '10 ETH', '10000 USD')

    withdraw('2018-01-15', '5 BTC', '1000 USD')
    withdraw('2018-01-20', '10 ETH', '1000 USD')
    trade('2018-01-25', '5 BTC', '500 ETH', '2000 USD')
    withdraw('2018-01-30', '250 ETH', '500 USD', wallet: wallet2)

    InvestmentsUpdater.call(user)
  end

  subject { described_class.call(user, dates, false) }

  it 'should create snapshots' do
    subject
    expect(clean_before_compare user.snapshots.order(date: :asc)).to match_snapshot('snapshots_updater')
  end

  it 'should not create snapshots again' do
    subject
    expect_any_instance_of(described_class).not_to receive(:load_rates)
    expect{ described_class.call(user, dates, false) }.not_to change { Snapshot.last.id }
  end

  it 'should delete snapshots if investments modified' do
    subject
    user.investments.order(date: :asc).first.touch(:updated_at)
    user.reload
    expect{ described_class.call(user, dates, false) }.to change { Snapshot.last.id }
    expect(clean_before_compare user.snapshots.order(date: :asc)).to match_snapshot('snapshots_updater')
  end

  context "with read_only" do
    subject { described_class.call(user, dates, true) }

    it 'should not create snapshots' do
      subject
      expect(clean_before_compare user.snapshots.order(date: :asc)).to eq([])
    end
  end

  context "with latest" do
    around { |example| Timecop.freeze(Time.utc(2020)) { example.run } }
    subject { described_class.call(user, dates + [Time.now], false) }

    it 'should create snapshots' do
      subject
      expect(clean_before_compare user.snapshots.order(date: :asc)).to match_snapshot('snapshots_updater2')
    end
  end

  def clean_before_compare(snapshots)
    snapshots = JSON.parse(snapshots.to_json)
    snapshots.each do |x|
      x['id'] = 'X'
      x['user_id'] = 'X'
      x['created_at'] = 'X'
      x['updated_at'] = 'X'
      x['date'] = 'X' if Time.parse(x['date']).beginning_of_day == Time.now.utc.beginning_of_day
      x['worths'] = x['worths'].inject({}) do |memo, (key, worth)|
        memo[Currency.find(key).symbol] = worth
        memo
      end
    end
    snapshots
  end
end
