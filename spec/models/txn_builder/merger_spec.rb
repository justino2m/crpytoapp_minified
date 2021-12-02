require 'rails_helper'

RSpec.describe TxnBuilder::Merger do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet, user: user) }
  let(:wallet2) { create(:wallet, user: user) }
  let!(:currency) { create(:btc) }
  let(:eth) { create(:eth) }
  let(:date) { '2018-01-01 00:00'.to_datetime }

  describe "#unmerge_entries!" do
    let(:txn) do
      txn = transfer('2018-01-01 00:00', '10 BTC', wallet2, to_amount: '9 BTC')
      txn.entries.create!(date: date, amount: 0.5, account_id: txn.from_account_id, adjustment: true, fee: false)
      txn
    end

    it 'should delete all fees, adjustments and entries for the specified account' do
      txn.label = 'ignored'
      txn.txhash = '1234'
      txn.unmerge_entries!(txn.from_account_id)
      expect(txn.from_amount).to eq 0
      expect(txn.to_amount).to eq 9
      expect(txn.from_account_id).to eq nil
      expect(txn.label).to eq nil
      expect(txn.importer_tag).to eq nil
      expect(txn.txhash).to eq '1234'
      expect(txn.entries.reload.count).to eq 1
    end
  end

  describe "#merge_transfer!" do
    let!(:dep) { deposit(date, '4.95 BTC', nil, label: 'ignored', wallet: wallet2) }
    let!(:withdrawal) { withdraw(date, '5 BTC') }

    it 'should create adjustment instead of modifying from_entry' do
      expect(Transaction.count).to be 2 # ensure its not auto merged
      dep.update_attributes! label: nil
      dep.merge_transfer! withdrawal.entries.map(&:dup)
      expect(dep.transfer?).to be true
      expect(dep.from_amount).to eq 4.95
      expect(dep.to_amount).to eq 4.95
      expect(dep.fee_amount).to eq 0.05
      expect(dep.entries.where(adjustment: true).first.amount). to eq 0.05
      expect(dep.entries.where(adjustment: false, fee: false).where('amount > 0').first.amount). to eq 4.95
      expect(dep.entries.where(adjustment: false, fee: false).where('amount < 0').first.amount). to eq -5
      expect(dep.entries.where(fee: true).first.amount).to eq -0.05
    end
  end

  describe "#update_from_entries" do
    it 'should detect trade' do

    end

    it 'should detect transfer and set date as last entry date' do

    end

    it 'should detect deposit' do

    end

    it 'should detect withdrawal' do

    end

    it 'should set sources' do

    end

    it 'should not override original importer_tag' do

    end

    it 'should not override user-specified txhash' do

    end
  end

  describe ".merge_transfer_txn!" do
    let(:date) { Time.parse('2018-01-01') }
    let(:deposit_attrs) { { txhash: '12345', to_currency: currency, to_amount: 14.5, date: date + 1.second }}
    let!(:deposit) { TxnBuilder::Deposit.create!(user, wallet, deposit_attrs) }
    let!(:withdrawal) { TxnBuilder::Withdrawal.create!(user, wallet2, txhash: '6789', from_currency: eth, from_amount: 15, date: date) }

    before do
      # if currency is same then it will auto-merge so we udpate currency manually for the deposit
      eth_account = wallet.accounts.create(currency: eth, user: user)
      deposit.update_attributes!(to_currency: eth, to_account_id: eth_account.id)
      deposit.entries.update_all(account_id: eth_account.id)
      deposit_attrs.merge!(to_currency: eth)
      deposit.reload
    end

    it 'should merge withdrawal into deposit and delete withdrawal' do
      expect(deposit.potential_match).to eq withdrawal
      expect{ deposit.merge_transfer_txn!(deposit.potential_match) }.to change { Transaction.count }.by -1
      expect(deposit.reload.type).to eq 'transfer'
      expect(deposit.from_amount).to eq 14.5
      expect(deposit.to_amount).to eq 14.5
      expect(deposit.fee_amount).to eq 0.5
      expect(deposit.date).to eq(date + 1.second) # date comes from the deposit for transfers
    end

    it 'should merge deposit into withdrawal and delete deposit' do
      expect(withdrawal.reload.potential_match).to eq deposit
      expect(TxnBuilder::Deposit.create!(user, wallet, deposit_attrs)).to eq nil # duplicate
      expect{ withdrawal.merge_transfer_txn!(withdrawal.potential_match) }.to change { Transaction.count }.by -1
      expect(withdrawal.reload.type).to eq 'transfer'
      expect(withdrawal.from_amount).to eq 14.5
      expect(withdrawal.to_amount).to eq 14.5
      expect(withdrawal.fee_amount).to eq 0.5
      expect(withdrawal.date).to eq(date + 1.second)
      expect(TxnBuilder::Deposit.create!(user, wallet, deposit_attrs)).to eq nil # should still detect duplicate
    end
  end
end
