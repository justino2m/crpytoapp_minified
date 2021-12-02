require 'rails_helper'

RSpec.describe TxnBuilder::Transfer do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet) }
  let(:wallet2) { create(:wallet) }
  let(:account) { create(:account, wallet: wallet, currency: btc, user: user) }
  let(:account2) { create(:account, wallet: wallet2, currency: btc, user: user) }
  let(:btc) { create(:btc) }
  let(:params) { { date: 10.minutes.ago, from_amount: '1000', from_currency: btc, to_amount: 999, to_wallet: wallet2 } }
  subject { described_class.new(user, wallet, params) }

  describe "#valid?" do
    it { should be_valid }
    it { should validate_presence_of :from_currency }
    it { should validate_presence_of :from_amount }
    it { should validate_presence_of :to_amount }
    it { should validate_numericality_of(:from_amount).is_greater_than 0 }
    it { should validate_numericality_of(:to_amount).is_greater_than 0 }

    it 'should not be valid if date is missing' do
      params[:date] = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:date]).to eq ['is invalid']
    end

    it 'should not be valid if to wallet is missing' do
      params[:to_wallet] = nil
      expect(subject).not_to be_valid
      expect(subject.errors[:to_wallet_id]).to eq ['cant be blank']
    end

    it 'should not be valid if to wallet is same as from wallet' do
      params[:to_wallet] = wallet
      expect(subject).not_to be_valid
      expect(subject.errors[:to_wallet_id]).to eq ['should not be same as From wallet']
    end
  end

  describe "#create" do
    it { should be_valid }

    it 'should create a transfer' do
      txn = subject.create!
      expect(txn.type).to eq Transaction::TRANSFER
      expect(txn.from_amount).to eq 999
      expect(txn.from_currency).to eq btc
      expect(txn.to_amount).to eq 999
      expect(txn.to_currency).to eq btc
      expect(txn.fee_amount).to eq 1
      expect(txn.fee_currency).to eq btc
      expect(txn.date).to eq params[:date].change(usec: 0).utc
    end
  end

  describe "#duplicate?" do
    it 'should return true with loose checks' do
      params[:loose_duplicate_checks] = true
      entry = create(:entry, account: account, user: user, date: (params[:date] - 50.seconds), amount: -999) # 1 is subtracted and added as fee
      entry2 = create(:entry, account: account2, user: user, date: (params[:date] + 50.seconds), amount: 999)
      expect(subject.send(:duplicate?)).to be false
      entry.update_columns(created_at: 5.second.ago)
      expect(subject.send(:duplicate?)).to be false
      entry2.update_columns(created_at: 5.second.ago)
      expect(subject.send(:duplicate?)).to be true
    end
  end
end
