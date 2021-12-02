require 'rails_helper'

RSpec.describe EntryBalanceUpdater, type: :model do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet, user: user) }
  let(:mkr) { create(:currency, symbol: 'MKR') }
  let(:bnb) { create(:currency, symbol: 'BNB') }
  let(:btc) { create(:currency, symbol: 'BTC') }
  let!(:txns) do
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-02 00:00 UTC', to_amount: 100, to_currency: btc)
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-03 00:00 UTC', to_amount: 100, to_currency: btc)
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-04 00:00 UTC', to_amount: 100, to_currency: btc)
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 00:00 UTC', to_amount: 100, to_currency: btc)
  end
  let(:expected_balances) { [100, 200, 300, 400] }

  subject { described_class.call(user) }

  it 'should update balances' do
    subject
    expect(user.entries.ordered.pluck(:balance)).to eq(expected_balances)
    expect(user.accounts.first.balance).to eq(expected_balances.last)
  end

  context "when new txn is added" do
    let(:expected_balances) { [100, 200, 300, 350, 450] }

    it 'should update subsequent balances' do
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-03 05:00 UTC', to_amount: 50, to_currency: btc)
      subject
      expect(user.entries.ordered.pluck(:balance)).to eq(expected_balances)
      expect(user.accounts.first.balance).to eq(expected_balances.last)
    end
  end

  context "when txn is deleted" do
    let(:expected_balances) { [100, 200, 300] }

    it 'should update subsequent balances' do
      Transaction.where(date: '2018-01-03 00:00 UTC').destroy_all
      subject
      expect(user.entries.ordered.pluck(:balance)).to eq(expected_balances)
      # expect(user.accounts.first.balance).to eq(expected_balances.last) # account balance has to be updated manually post deletion
    end
  end

  context "with negative balances" do
    let!(:txns) do
      TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-01 00:00 UTC', from_amount: 200, from_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 01:05 UTC', to_amount: 100, to_currency: btc)
      TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-03 00:00 UTC', from_amount: 100, from_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-03 00:50 UTC', to_amount: 100, to_currency: btc)
    end
    let(:expected_balances) { [-200, -100, -200, -100] }
    let(:negative_balances) { [true, false, false, false] }

    it 'should set negative balances' do
      subject
      described_class.call(user) # second call shouldnt change anything
      expect(user.entries.ordered.pluck(:balance)).to eq(expected_balances)
      expect(user.entries.ordered.pluck(:negative)).to eq(negative_balances)
      expect(user.txns.order(date: :asc).map(&:negative_balances)).to eq(negative_balances)
      expect(user.accounts.first.balance).to eq(expected_balances.last)
    end

    context "when another withdrawal reduces lowest balance further" do
      let!(:txns) do
        TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-01 00:00 UTC', from_amount: 200, from_currency: btc)
        TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 01:00 UTC', to_amount: 100, to_currency: btc)
        TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-03 00:00 UTC', from_amount: 300, from_currency: btc)
        TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-03 01:00 UTC', to_amount: 100, to_currency: btc)
      end
      let(:expected_balances) { [-200, -100, -400, -300] }
      let(:negative_balances) { [true, false, true, false] }

      it 'should still set negative balances' do
        subject
        expect(user.entries.ordered.pluck(:balance)).to eq(expected_balances)
        expect(user.entries.ordered.pluck(:negative)).to eq(negative_balances)
        expect(user.txns.order(date: :asc).map(&:negative_balances)).to eq(negative_balances)
        expect(user.accounts.first.balance).to eq(expected_balances.last)
      end
    end
  end

  context "when a txn results in 2 negative balances" do
    let!(:txns) do
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 00:00 UTC', to_amount: 100, to_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-02 00:00 UTC', to_amount: 100, to_currency: btc)
      TxnBuilder::Trade.create!(user, wallet, date: '2018-01-03 00:00 UTC', from_amount: 300, from_currency: btc, to_amount: 100, to_currency: mkr, fee_amount: 5, fee_currency: bnb)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-03 10:00 UTC', to_amount: 100, to_currency: btc)
    end
    let(:expected_balances) { { btc: [100, 200, -100, 0], mkr: [100], bnb: [-5] } }
    let(:negative_balances) { [false, false, true, false] }

    it 'should set negative balances' do
      subject
      expected_balances.each do |k, v|
        account = user.accounts.find_by(currency: Currency.find_by(symbol: k.upcase))
        expect(account.entries.ordered.pluck(:balance)).to eq(v)
        expect(account.balance).to eq(v.last)
      end
      expect(user.txns.order(date: :asc).map(&:negative_balances)).to eq(negative_balances)
    end

    context "when one of the entries becomes positive" do
      let(:expected_balances) { { btc: [100, 200, 300, 0, 100], mkr: [100], bnb: [-5] } }
      let(:negative_balances) { [false, false, false, true, false] }
      before { described_class.call(user) }

      it 'should still set txn to negative' do
        TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-02 23:00 UTC', to_amount: 100, to_currency: btc)
        subject
        expected_balances.each do |k, v|
          account = user.accounts.find_by(currency: Currency.find_by(symbol: k.upcase))
          expect(account.entries.ordered.pluck(:balance)).to eq(v)
          expect(account.balance).to eq(v.last)
        end
        expect(user.txns.order(date: :asc).map(&:negative_balances)).to eq(negative_balances)
      end
    end
  end

  context "when multiple entries at same time" do
    let!(:txns) do
      TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-01 00:00 UTC', from_amount: 50, from_currency: btc)
      TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-01 00:00 UTC', from_amount: 500, from_currency: btc)
      TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-01 00:00 UTC', from_amount: 500, from_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 00:00 UTC', to_amount: 300, to_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 00:00 UTC', to_amount: 400, to_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 00:00 UTC', to_amount: 200, to_currency: btc)

      TxnBuilder::Withdrawal.create!(user, wallet, date: '2018-01-02 00:00 UTC', from_amount: 850, from_currency: btc)
      TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-02 00:00 UTC', to_amount: 750, to_currency: btc)
    end
    let(:expected_amounts) { [400, 300, 200, -50, -500, -500, 750, -850] }
    let(:expected_balances) { [400, 700, 900, 850, 350, -150, 600, -250] }
    let(:negative_balances) { [false, false, false, false, false, true, false, true] }

    it 'should set negative balances' do
      subject
      expect(user.entries.ordered.pluck(:balance)).to eq(expected_balances)
      expect(user.entries.ordered.pluck(:negative)).to eq(negative_balances)
      expect(user.txns.order(date: :asc).where(negative_balances: true).count).to eq 2
      expect(user.accounts.first.balance).to eq(expected_balances.last)
    end
  end
end
