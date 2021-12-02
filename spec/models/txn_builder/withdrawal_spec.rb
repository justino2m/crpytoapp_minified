require 'rails_helper'

RSpec.describe TxnBuilder::Withdrawal do
  let(:user) { create(:user) }
  let(:btc) { create(:btc) }
  let(:wallet) { create(:wallet) }
  let(:account) { create(:account, wallet: wallet, currency: btc, user: user) }
  let(:params) { { date: 10.minutes.ago, from_amount: '10', from_currency: btc } }
  subject { described_class.new(user, wallet, params) }

  describe "#valid?" do
    it { should validate_presence_of :from_amount }
    it { should validate_presence_of :from_currency }
    it { should validate_numericality_of(:from_amount).is_greater_than 0 }

    it 'should not be valid if date is missing' do
      params[:date] = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:date]).to eq ['is invalid']
    end
  end

  describe "#create" do
    it { should be_valid }

    it 'should create a withdrawal' do
      txn = subject.create!
      expect(txn.type).to eq Transaction::CRYPTO_WITHDRAWAL
      expect(txn.from_amount).to eq 10
      expect(txn.from_currency).to eq btc
      expect(txn.date).to eq params[:date].change(usec: 0).utc
    end

    context "when matching deposit exists" do
      let!(:dep) do
        deposit(params[:date], '10 BTC', '100 USD', txhash: '1234', wallet: create(:wallet, user: wallet.user))
      end

      it 'should create a transfer and update account totals' do
        expect(dep.to_account.balance).to eq 10
        params[:txhash] = '1234'
        txn = subject.create!
        expect(txn.type).to eq Transaction::TRANSFER
        expect(txn.to_account.balance).to eq 10
        expect(txn.from_account.balance).to eq -10
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
      entry = create(:entry, account: account, user: user, external_id: '1234', date: (params[:date] + 5.seconds), amount: -10)
      expect(subject.send(:duplicate?)).to be false
      entry.update_columns(created_at: 1.second.ago)
      expect(subject.send(:duplicate?)).to be true
    end
  end

  describe "#create_or_merge_grouped_txn" do
    let!(:btc) { create(:btc) }

    it 'should merge into existing group' do
      withdraw('2019-01-01 01:00', '10 BTC', nil, group_name: 'grouped')
      withdraw('2019-01-01 01:20', '10 BTC', nil, group_name: 'grouped')
      withdraw('2019-01-01 01:30', '10 BTC', nil, group_name: 'grouped')
      expect(Transaction.count).to eq 1
      expect(Entry.count).to eq 1
      txn = Transaction.first
      expect(txn.from_amount).to eq 30
      expect(Entry.first.amount).to eq -30
      expect(txn.group_date).to eq '2019-01-01 01:00'.to_datetime.beginning_of_day
      expect(txn.group_from).to eq '2019-01-01 01:00'.to_datetime
      expect(txn.group_to).to eq '2019-01-01 01:30'.to_datetime
    end

    it 'should not merge into existing group' do
      withdraw('2019-01-01 01:00', '10 BTC', nil, group_name: 'grouped')
      withdraw('2019-01-01 01:30', '10 BTC', nil, group_name: 'grouped')
      withdraw('2019-01-01 01:20', '10 BTC', nil, group_name: 'grouped') # this should be skipped
      expect(Transaction.count).to eq 1
      expect(Entry.count).to eq 1
      txn = Transaction.first
      expect(txn.from_amount).to eq 20
      expect(Entry.first.amount).to eq -20
      expect(txn.group_date).to eq '2019-01-01 01:00'.to_datetime.beginning_of_day
      expect(txn.group_from).to eq '2019-01-01 01:00'.to_datetime
      expect(txn.group_to).to eq '2019-01-01 01:30'.to_datetime
    end
  end
end
