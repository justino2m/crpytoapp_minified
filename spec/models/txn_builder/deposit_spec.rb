require 'rails_helper'

RSpec.describe TxnBuilder::Deposit do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet) }
  let(:account) { create(:account, wallet: wallet, currency: btc, user: user) }
  let(:btc) { create(:btc) }
  let(:params) { { date: 10.minutes.ago, to_amount: '10', to_currency: btc } }
  subject { described_class.new(user, wallet, params) }

  describe "#valid?" do
    it { should validate_presence_of :to_amount }
    it { should validate_presence_of :to_currency }
    it { should validate_numericality_of(:to_amount).is_greater_than 0 }

    it 'should not be valid if date is missing' do
      params[:date] = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:date]).to eq ['is invalid']
    end

    it 'should not be valid if date is too low' do
      params.merge!(date: 1000.years.ago)
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ["Date is out of bounds/invalid"]
    end

    it 'should not be valid if date is too high' do
      params.merge!(date: 1000.years.from_now)
      expect(subject).not_to be_valid
      expect(subject.errors.full_messages).to eq ["Date is out of bounds/invalid"]
    end

    it 'should be valid with a timestamp' do
      date = DateTime.parse("2018-01-01 00:00 UTC")
      params.merge!(date: date.to_i)
      expect(subject).to be_valid
      expect(subject.date).to eq date
    end

    it 'should be valid with a millisecond timestamp' do
      date = DateTime.parse("2018-01-01 00:00 UTC")
      params.merge!(date: (date.to_f * 1000).to_i)
      expect(subject).to be_valid
      expect(subject.date).to eq date
    end
  end

  describe "#create" do
    it { should be_valid }

    it 'should create a deposit' do
      txn = subject.create!
      expect(txn.type).to eq Transaction::CRYPTO_DEPOSIT
      expect(txn.to_amount).to eq 10
      expect(txn.to_currency).to eq btc
      expect(txn.date).to eq params[:date].change(usec: 0).utc
    end

    context "when matching withdrawal exists" do
      let!(:withdrawal) do
        withdraw(params[:date], '10 BTC', '100 USD', txhash: '1234', wallet: create(:wallet, user: wallet.user))
      end

      it 'should create a transfer and update account totals' do
        expect(withdrawal.from_account.balance).to eq -10
        params[:txhash] = '1234'
        txn = subject.create!
        expect(txn.type).to eq Transaction::TRANSFER
        expect(txn.to_account.balance).to eq 10
        expect(txn.from_account.balance).to eq -10
      end
    end

    context "when date with timezone supplied" do
      it 'should equal timezone date' do
        expect(TxnBuilder::Helper.normalize_date("1/1/2018 14:00").to_s).to eq "2018-01-01 14:00:00 +0000"
        expect(TxnBuilder::Helper.normalize_date("1/1/2018 14:00 +7").to_s).to eq "2018-01-01 14:00:00 +0700"
        expect(TxnBuilder::Helper.normalize_date("1/1/2018 14:00", "Pacific/Fiji").to_s).to eq "2018-01-01 14:00:00 +1300"
        expect(TxnBuilder::Helper.normalize_date("1/1/2018 14:00 GMT+12 (Pacific/Fiji)", "UTC").to_s).to eq "2018-01-01 14:00:00 +0000"
      end
    end
  end

  describe "#duplicate?" do
    it 'should return true' do
      params[:external_id] = '1234'
      create(:entry, account: account, user: user, external_id: '1234')
      expect(subject.send(:duplicate?)).to be true
    end

    it 'should return true with loose checks' do
      params[:loose_duplicate_checks] = true
      entry = create(:entry, account: account, user: user, external_id: '1234', date: (params[:date] - 5.seconds), amount: 10)
      expect(subject.send(:duplicate?)).to be false
      entry.update_columns(created_at: 1.second.ago)
      expect(subject.send(:duplicate?)).to be true
    end
  end

  describe "#create_or_merge_grouped_txn" do
    let!(:btc) { create(:btc) }

    it 'should merge into existing group' do
      deposit('2019-01-01 01:00', '10 BTC', nil, group_name: 'grouped')
      deposit('2019-01-01 01:20', '10 BTC', nil, group_name: 'grouped')
      deposit('2019-01-01 01:30', '10 BTC', nil, group_name: 'grouped')
      expect(Transaction.count).to eq 1
      expect(Entry.count).to eq 1
      txn = Transaction.first
      expect(txn.to_amount).to eq 30
      expect(Entry.first.amount).to eq 30
      expect(txn.group_date).to eq '2019-01-01 01:00'.to_datetime.beginning_of_day
      expect(txn.group_from).to eq '2019-01-01 01:00'.to_datetime
      expect(txn.group_to).to eq '2019-01-01 01:30'.to_datetime
    end

    it 'should not merge into existing group' do
      deposit('2019-01-01 01:00', '10 BTC', nil, group_name: 'grouped')
      deposit('2019-01-01 01:30', '10 BTC', nil, group_name: 'grouped')
      deposit('2019-01-01 01:20', '10 BTC', nil, group_name: 'grouped') # this should be skipped
      expect(Transaction.count).to eq 1
      expect(Entry.count).to eq 1
      txn = Transaction.first
      expect(txn.to_amount).to eq 20
      expect(Entry.first.amount).to eq 20
      expect(txn.group_date).to eq '2019-01-01 01:00'.to_datetime.beginning_of_day
      expect(txn.group_from).to eq '2019-01-01 01:00'.to_datetime
      expect(txn.group_to).to eq '2019-01-01 01:30'.to_datetime
    end
  end
end
