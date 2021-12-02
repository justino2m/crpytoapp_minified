require 'rails_helper'

RSpec.describe TxnBuilder::Trade do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet) }
  let!(:usd) { create(:usd) }
  let!(:btc) { create(:btc) }
  let!(:eth) { create(:eth) }
  let(:account) { create(:account, wallet: wallet, currency: btc, user: user) }
  let(:account_usd) { create(:account, wallet: wallet, currency: usd, user: user) }
  let(:params) { { date: 10.minutes.ago, from_amount: '1000', from_currency: 'USD', to_amount: '10.0', to_currency: 'BTC', txhash: '1234' } }
  subject { described_class.new(user, wallet, params) }

  describe "#valid?" do
    it { should validate_presence_of :from_amount }
    it { should validate_presence_of :from_currency }
    it { should validate_presence_of :to_amount }
    it { should validate_presence_of :to_currency }
    it { should validate_numericality_of(:to_amount).is_greater_than 0 }
    it { should validate_numericality_of(:from_amount).is_greater_than 0 }

    it 'should not be valid if date is missing' do
      params[:date] = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:date]).to eq ['is invalid']
    end

    it 'should not be valid if from and to currencies are same' do
      params[:from_currency] = btc
      expect(subject).not_to be_valid
      expect(subject.errors[:from_currency_id]).to eq ['should not be same as To currency']
    end
  end

  describe "#create" do
    it { should be_valid }

    it 'should create an exchange' do
      txn = subject.create!
      expect(txn.type).to eq Transaction::BUY
      expect(txn.from_amount).to eq 1000
      expect(txn.from_currency).to eq usd
      expect(txn.to_amount).to eq 10
      expect(txn.to_currency).to eq btc
      expect(txn.date).to eq params[:date].change(usec: 0).utc
    end
  end

  describe "#duplicate?" do
    it 'should return true with loose checks' do
      params[:loose_duplicate_checks] = true
      entry = create(:entry, account: account, user: user, date: (params[:date] - 5.seconds), amount: 10)
      entry2 = create(:entry, account: account_usd, user: user, date: (params[:date] + 5.seconds), amount: -1000)
      expect(subject.send(:duplicate?)).to be false
      entry.update_columns(created_at: 5.second.ago)
      expect(subject.send(:duplicate?)).to be false
      entry2.update_columns(created_at: 5.second.ago)
      expect(subject.send(:duplicate?)).to be true
    end
  end

  describe "#existing_txn" do
    let!(:existing) { trade(1.hour.ago, '50 USD', '5 BTC', nil, txhash: '1234', fee: '0.01 BTC') }
    subject{ described_class.new(user, wallet, params).send :existing_txn }

    it 'should not return existing txn if hash is different' do
      params[:txhash] = 'asdad'
      expect(subject).to be nil
    end

    it 'should return existing txn with same hash' do
      expect(subject).to eq existing
    end

    it 'should return existing txn if fee currency is same on this one' do
      params[:fee_amount] = '0.01'
      params[:fee_currency] = 'BTC'
      expect(subject).to eq existing
    end

    it 'should not return existing txn if fee currency is different' do
      params[:fee_amount] = '0.01'
      params[:fee_currency] = 'ETH'
      expect(subject).to be nil
    end

    context "when duplicate exists" do
      let!(:adapter) { TxnBuilder::Adapter.new(user, wallet, true) }
      let!(:txn) { trade('2018-01-01', '1 BTC', '2 ETH', '1000 USD', fee: '0.05 ETH', txhash: '12345', external_id: '12345', adapter: adapter )}

      around do |ex|
        old = TxnBuilder::Trade::MAX_TRADES_PER_ORDER
        ex.run
        TxnBuilder::Trade::MAX_TRADES_PER_ORDER = old
      end

      it 'should return the last pending duplicate txn' do
        # this should create a new txn
        TxnBuilder::Trade::MAX_TRADES_PER_ORDER = 2
        txn2 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '654321', adapter: adapter)
        expect(txn2).not_to be_persisted
        expect(txn2).not_to eq txn
        expect(txn2.from_amount).to eq 2
        expect(txn2.to_amount).to eq 4

        # this should merge into the previous txn
        TxnBuilder::Trade::MAX_TRADES_PER_ORDER = 4
        txn3 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '789456', adapter: adapter)
        expect(txn3).to eq txn2
        expect(txn3.from_amount).to eq 4
        expect(txn3.to_amount).to eq 8

        # these should not be added as they are duplicates
        txn4 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '12345', adapter: adapter)
        expect(txn4).to be nil
        txn4 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '789456', adapter: adapter)
        expect(txn4).to be nil
      end

      it 'should return the last saved duplicate txn' do
        TxnBuilder::Trade::MAX_TRADES_PER_ORDER = 2
        txn2 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '654321', adapter: adapter)
        adapter.commit!
        expect(txn2).to be_persisted
        expect(txn2.id).not_to eq txn.id
        expect(txn2.from_amount).to eq 2
        expect(txn2.to_amount).to eq 4

        TxnBuilder::Trade::MAX_TRADES_PER_ORDER = 4
        txn3 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '789456', adapter: adapter)
        expect(txn3).to eq txn2
        txn3.reload
        expect(txn3.from_amount).to eq 4
        expect(txn3.to_amount).to eq 8

        # these should not be added as they are duplicates
        txn4 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '12345', adapter: adapter)
        expect(txn4).to be nil
        txn4 = trade('2018-01-01', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '789456', adapter: adapter)
        expect(txn4).to be nil
      end

      it 'should create new txn if trade is too far apart' do
        txn2 = trade('2018-01-01 02:00', '2 BTC', '4 ETH', '2000 USD', txhash: '12345', external_id: '654321', adapter: adapter)
        expect(txn2).not_to eq txn
        expect(txn2.from_amount).to eq 2
        expect(txn2.to_amount).to eq 4
      end
    end
  end
end
