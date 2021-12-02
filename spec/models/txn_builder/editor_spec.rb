require 'rails_helper'

RSpec.describe TxnBuilder::Editor do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet, user: user) }
  let(:wallet2) { create(:wallet, user: user) }
  let!(:btc) { create(:btc) }
  let!(:eth) { create(:eth) }
  let(:date) { '2018-01-01 00:00' }

  context "#create" do
    subject{ described_class.new(user) }

    it 'should create a deposit' do
      txn = subject.create!(
        date: date,
        type: 'deposit',
        to_amount: '10',
        to_currency_id: btc.id,
        to_wallet_id: wallet.id,
        label: 'airdrop'
      )
      expect(txn.type).to eq 'crypto_deposit'
      expect(txn.to_amount).to eq 10
      expect(txn.to_currency).to eq btc
      expect(txn.label).to eq 'airdrop'
    end

    it 'should create a withdrawal' do
      txn = subject.create!(
        date: date,
        type: 'withdrawal',
        from_amount: '10',
        from_currency_id: btc.id,
        from_wallet_id: wallet.id,
        label: 'cost'
      )
      expect(txn.type).to eq 'crypto_withdrawal'
      expect(txn.from_amount).to eq 10
      expect(txn.from_currency).to eq btc
      expect(txn.label).to eq 'cost'
    end

    it 'should create a trade' do
      txn = subject.create!(
        date: date,
        type: 'trade',
        from_amount: '10',
        from_currency_id: btc.id,
        from_wallet_id: wallet.id,
        to_amount: 5,
        to_currency_id: eth.id,
      )
      expect(txn.type).to eq 'exchange'
      expect(txn.from_amount).to eq 10
      expect(txn.from_currency).to eq btc
      expect(txn.to_amount).to eq 5
      expect(txn.to_currency).to eq eth
      expect(txn.label).to eq nil
      expect(txn.to_source).to eq nil
      expect(txn.from_source).to eq nil
    end

    it 'should create a transfer' do
      txn = subject.create!(
        date: date,
        type: 'transfer',
        from_amount: '10',
        from_currency_id: btc.id,
        from_wallet_id: wallet.id,
        to_amount: 5,
        to_currency_id: btc.id,
        to_wallet_id: wallet2.id,
      )
      expect(txn.type).to eq 'transfer'
      expect(txn.from_amount).to eq 5
      expect(txn.from_currency).to eq btc
      expect(txn.to_amount).to eq 5
      expect(txn.to_currency).to eq btc
      expect(txn.fee_amount).to eq 5
      expect(txn.fee_currency).to eq btc
      expect(txn.label).to eq nil
    end

    it 'should raise error if adding to another users account' do
      expect{
        described_class.new(create(:user)).create!(
          date: date,
          type: 'deposit',
          to_amount: '10',
          to_currency_id: btc.id,
          to_wallet_id: wallet.id,
          label: 'airdrop'
        )
      }.to raise_error ActiveRecord::RecordNotFound
    end
  end

  context "#update" do
    subject{ described_class.new(user, txn) }

    context "with deposit" do
      let(:attrs) { { type: 'deposit', date: txn.date, to_amount: 10, to_currency_id: btc.id, to_wallet_id: wallet.id, label: 'fork' } }
      let!(:txn) { deposit(date, '10 BTC', nil) }

      it 'should update amount' do
        txn = subject.update!(attrs.merge(to_amount: 5, to_currency_id: eth.id))
        expect(txn.to_amount).to eq 5
        expect(txn.to_currency).to eq eth
      end

      it 'should update txhash without updating from entries' do
        expect_any_instance_of(described_class).not_to receive(:shallow_update!)
        last_id = txn.entries.first.id
        txn = subject.update!(attrs.merge(txhash: '1234', label: 'airdrop'))
        expect(txn.entries.first.id).to eq last_id
        expect(txn.entries.reload.first.id).to eq last_id
        expect(txn.txhash).to eq '1234'
        expect(txn.label).to eq 'airdrop'
      end

      it 'should update net worth and recalc net value' do
        txn = subject.update!(attrs.merge(net_worth_amount: 20, net_worth_currency_id: user.base_currency.id))
        expect(txn.net_value).to eq 20
      end

      it 'should update net worth and recalc net value even when shallow updating' do
        txn = subject.update!(net_worth_amount: 20, net_worth_currency_id: user.base_currency.id)
        expect(txn.net_value).to eq 20
      end

      it 'should allow shallow updating when only some things specified' do
        last_id = txn.entries.first.id
        txn = subject.update!(txhash: '1234', label: 'airdrop')
        expect(txn.entries.first.id).to eq last_id
        expect(txn.entries.reload.first.id).to eq last_id
        expect(txn.txhash).to eq '1234'
        expect(txn.label).to eq 'airdrop'
      end

      it 'should update date' do
        txn = subject.update!(attrs.merge(date: date.to_datetime+5.days))
        expect(txn.date).to eq date.to_datetime+5.days
      end

      it 'should turn it into withdrawal' do
        txn = subject.update!(attrs.merge(type: 'withdrawal', from_amount: 10, from_currency_id: btc.id, from_wallet_id: wallet.id, label: 'cost'))
        expect(txn.entries.count).to eq 1
        expect(txn.type).to eq 'crypto_withdrawal'
        expect(txn.from_amount).to eq 10
        expect(txn.from_currency).to eq btc
        expect(txn.label).to eq 'cost'
      end

      it 'should turn it into trade' do
        txn = subject.update!(attrs.merge(
          type: 'trade',
          from_amount: '10',
          from_currency_id: btc.id,
          from_wallet_id: wallet.id,
          to_amount: 5,
          to_currency_id: eth.id,
        ))
        expect(txn.type).to eq 'exchange'
        expect(txn.from_amount).to eq 10
        expect(txn.from_currency).to eq btc
        expect(txn.to_amount).to eq 5
        expect(txn.to_currency).to eq eth
        expect(txn.label).to eq nil
        expect(txn.to_source).to eq nil
        expect(txn.from_source).to eq nil
      end

      it 'should turn it into transfer' do
        txn = subject.update!(attrs.merge(
          type: 'transfer',
          from_amount: '10',
          from_currency_id: btc.id,
          from_wallet_id: wallet.id,
          to_amount: 5,
          to_currency_id: btc.id,
          to_wallet_id: wallet2.id,
        ))
        expect(txn.type).to eq 'transfer'
        expect(txn.from_amount).to eq 5
        expect(txn.from_currency).to eq btc
        expect(txn.to_amount).to eq 5
        expect(txn.to_currency).to eq btc
        expect(txn.fee_amount).to eq 5
        expect(txn.fee_currency).to eq btc
        expect(txn.label).to eq nil
        expect(txn.entries.count).to eq 3
        expect(txn.entries.select{ |x| x.amount > 0 && !x.fee?}.first.amount).to eq 5
        expect(txn.entries.select{ |x| x.amount < 0 && !x.fee?}.first.amount).to eq -5
        expect(txn.entries.select{ |x| x.fee? }.first.amount).to eq -5
      end
    end

    context "with synced deposit" do
      let(:attrs) { { type: 'deposit', date: txn.date, to_amount: 10, to_currency_id: btc.id, to_wallet_id: wallet.id, label: 'fork' } }
      let!(:txn) { deposit(date, '10 BTC', nil) }

      before do
        txn.update_attributes! to_source: 'api'
        txn.entries.first.update_attributes! synced: true
      end

      it 'should raise error if amount changed' do
        expect{ subject.update!(attrs.merge(to_amount: 5)) }.to raise_error TxnBuilder::Error, "Received part of the txn cant be modified"
      end

      it 'should raise error if date changed' do
        subject.update!(attrs.merge(date: date.to_datetime+5.days))
        expect(txn.reload.date).to eq date.to_datetime # shouldnt change
      end

      it 'should update label and txhash' do
        last_id = txn.entries.first.id
        txn = subject.update!(attrs.merge(txhash: '1234', label: 'airdrop'))
        expect(txn.entries.first.id).to eq last_id
        expect(txn.entries.reload.first.id).to eq last_id
        expect(txn.txhash).to eq '1234'
        expect(txn.label).to eq 'airdrop'
      end

      it 'should turn it into transfer without modifying synced entry' do
        txn = subject.update!(attrs.merge(
          type: 'transfer',
          from_amount: '15',
          from_currency_id: btc.id,
          from_wallet_id: wallet2.id,
          to_amount: 10,
          to_currency_id: eth.id,
          to_wallet_id: wallet.id,
        ))
        expect(txn.type).to eq 'transfer'
        expect(txn.from_amount).to eq 10
        expect(txn.from_currency).to eq btc
        expect(txn.to_amount).to eq 10
        expect(txn.to_currency).to eq btc
        expect(txn.fee_amount).to eq 5
        expect(txn.fee_currency).to eq btc
        expect(txn.label).to eq nil
        expect(txn.entries.count).to eq 3
        expect(txn.entries.select{ |x| x.amount > 0 && !x.fee? }.first.amount).to eq 10
        expect(txn.entries.select{ |x| x.amount < 0 && !x.fee? }.first.amount).to eq -10
        expect(txn.entries.select{ |x| x.fee? }.first.amount).to eq -5
      end
    end

    context "with synced withdrawal" do
      let(:attrs) { { type: 'withdrawal', date: txn.date, from_amount: 10, from_currency_id: btc.id, from_wallet_id: wallet.id, label: 'ignored' } }
      let!(:txn) { withdraw(date, '10 BTC', nil) }

      before do
        txn.update_attributes! from_source: 'api'
        txn.entries.first.update_attributes! synced: true
      end

      it 'should raise error if trying to update from amount' do
        expect do
          subject.update!(attrs.merge(
            type: 'transfer',
            from_amount: '8',
            from_currency_id: btc.id,
            from_wallet_id: wallet.id,
            to_amount: 5,
            to_currency_id: eth.id,
            to_wallet_id: wallet2.id,
          ))
        end.to raise_error TxnBuilder::Error, "Sent part of the txn cant be modified"
      end

      it 'should turn it into transfer without modifying synced entry' do
        txn = subject.update!(attrs.merge(
          type: 'transfer',
          from_amount: '10',
          from_currency_id: btc.id,
          from_wallet_id: wallet.id,
          to_amount: 5,
          to_currency_id: eth.id,
          to_wallet_id: wallet2.id,
        ))
        expect(txn.type).to eq 'transfer'
        expect(txn.from_amount).to eq 5
        expect(txn.from_currency).to eq btc
        expect(txn.to_amount).to eq 5
        expect(txn.to_currency).to eq btc
        expect(txn.fee_amount).to eq 5
        expect(txn.fee_currency).to eq btc
        expect(txn.label).to eq nil
        expect(txn.entries.count).to eq 4
        expect(txn.entries.select{ |x| x.amount > 0 && !x.fee? }.first.amount).to eq 5
        expect(txn.entries.select{ |x| x.amount < 0 && !x.fee? }.first.amount).to eq -10
        expect(txn.entries.select{ |x| x.fee? }.first.amount).to eq -5
        expect(txn.entries.select{ |x| x.adjustment? }.first.amount).to eq 5
      end
    end
  end
end