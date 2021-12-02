require 'rails_helper'

RSpec.describe Transaction, type: :model do
  let!(:usd) { create(:usd) }
  let!(:eur) { create(:eur) }
  let(:user) { create(:user, base_currency: usd) }
  let(:wallet) { create(:wallet, user: user) }
  let(:date) { Time.now }

  # describe "#ordered" do
  #   let!(:btc) { create(:btc) }
  #   let!(:eth) { create(:eth) }
  #   let!(:wallet2) { create(:wallet, user: user) }
  #
  #   subject do
  #     # date: :asc, to_currency_id: :asc, to_amount: :desc, id: :asc
  #     user.txns.order("
  #       CASE
  #       WHEN
  #     ")
  #   end
  #
  #   before do
  #     withdraw('2018-01-01 00:00 UTC', '1 BTC')
  #     withdraw('2018-01-01 00:00 UTC', '2 BTC')
  #     withdraw('2018-01-01 00:00 UTC', '3 BTC', nil, wallet: wallet2)
  #     deposit('2018-01-01 00:00 UTC', '6 BTC')
  #     deposit('2018-01-01 00:00 UTC', '10 BTC')
  #     deposit('2018-01-01 00:00 UTC', '20 BTC')
  #     deposit('2018-01-01 00:00 UTC', '30 BTC', nil, wallet: wallet2)
  #     trade('2018-01-01 00:00 UTC', '10 BTC', '100 ETH')
  #     trade('2018-01-01 00:00 UTC', '300 ETH', '5 BTC')
  #     trade('2018-01-01 00:00 UTC', '50 BTC', '300 ETH', nil, wallet: wallet2)
  #     # transfer('2018-01-01 00:00 UTC', '15 BTC', wallet2)
  #     # transfer('2018-01-01 00:00 UTC', '25 BTC', wallet2)
  #     # transfer('2018-01-01 00:00 UTC', '35 BTC', wallet2)
  #   end
  #
  #   it 'should return txns in correct order' do
  #     txns = subject.map do |txn|
  #       prettify_txn(txn)
  #     end
  #     byebug
  #     txns
  #   end
  # end

  describe "#nullify_gains" do
    let(:txn) { transfer('2018-01-01', '10 USD', create(:wallet)) }

    it 'should nullify gain when type changes' do
      txn.gain = 100
      txn.save!
      txn = Transaction.last
      txn.type = 'crypto_deposit'
      txn.valid?

      # there is a bug in rails that causes saved_change_to_transaction_type? to return false in a before_update
      # callback - it cant be reproduced in test env, only dev or prod! so must ensure that we are calling
      # transaction_type_changed? in a before_update callback or saved_change_to_transaction_type? in an
      # after_update callback!
      expect(txn).to receive(:transaction_type_changed?).and_call_original
      txn.save
      expect(txn.gain).to eq nil
    end
  end

  describe "#update_totals" do
    before do
      [
        ['BTC'],
        ['LTC'],
        ['SEK', fiat: true],
        ['USDT', stablecoin: usd],
        ['EURT', stablecoin: eur],
      ].map { |x| create(:currency, (x[1] || {}).merge(name: x[0], symbol: x[0])) }
      Currency.all.each { |x| create(:rate, date: date - 1.minute, currency: x, quoted_rate: 2) }
      create(:currency, symbol: 'ABC') # no rates
      create(:currency, symbol: 'XYZ') # no rates
      txn.update_totals
    end

    describe "#update_totals.net_value" do
      subject { txn.net_value }

      # if a stablecoin goes bad i.e. 10 USD gives you 100 USDT - value should be 10
      # if a stablecoin goes bad i.e. 10 GBP gives you 100 EURT - value should be 10
      # if stablecoin goes nuts i.e. 10 USD gives you 5 USDT - value should be 10

      context "when net worth is present" do
        context "should prioritize to_amount when currency same as base" do
          let(:txn) { trade(date, '10 BTC', '100 USD', '111 USD') }
          it { is_expected.to eq 100 }
        end

        context "should prioritize from_amount when currency same as base" do
          let(:txn) { trade(date, '10 USD', '1 BTC', '111 USD') }
          it { is_expected.to eq 10 }
        end

        context "should return worth if neither to nor from match base" do
          let(:txn) { trade(date, '10 BTC', '5 LTC', '50 USD') }
          it { is_expected.to eq 50 }
        end

        context "should return worth if fiat-currency does not match base" do
          let(:txn) { trade(date, '10 BTC', '5 SEK', '50 EUR') }
          it { is_expected.to eq 100 }
        end

        context "should prioritize worth over to-stablecoin" do
          let(:txn) { trade(date, '10 BTC', '100 USDT', '120 SEK') }
          it { is_expected.to eq 240 }
        end

        context "should prioritize worth over from-stablecoin" do
          let(:txn) { trade(date, '10 USDT', '1 BTC', '50 USD') }
          it { is_expected.to eq 50 }
        end
      end

      context "should prioritize to-fiat" do
        let(:txn) { trade(date, '10 BTC', '25 EUR') }
        it { is_expected.to eq 50 }
      end

      context "should prioritize from-fiat when to is not fiat" do
        let(:txn) { trade(date, '10 EUR', '5 LTC') }
        it { is_expected.to eq 20 }
      end

      context "should prioritize to-fiat over stablecoin" do
        let(:txn) { trade(date, '10 EURT', '100 EUR') }
        it { is_expected.to eq 200 }
      end

      context "should prioritize from-fiat over stablecoin" do
        let(:txn) { trade(date, '10 EUR', '100 EURT') }
        it { is_expected.to eq 20 }
      end

      context "should prioritize stablecoin over crypto" do
        let(:txn) { trade(date, '10 EURT', '5 LTC') }
        it { is_expected.to eq 20 }
      end

      context "should prioritize to-stablecoin when both are stable" do
        let(:txn) { trade(date, '10 USDT', '15 EURT') }
        it { is_expected.to eq 30 }
      end

      context "should prioritize to-currency" do
        let(:txn) { trade(date, '10 BTC', '5 LTC') }
        it { is_expected.to eq 10 }
      end

      context "should prioritize from currency if to currency doesnt have a rate" do
        let(:txn) { trade(date, '10 BTC', '25 XYZ') }
        it { is_expected.to eq 20 }
      end

      context "should be zero when no rates" do
        let(:txn) { trade(date, '10 ABC', '25 XYZ') }
        it { is_expected.to eq 0 }

        it 'should set missing_rates' do
          expect(txn.missing_rates).to be true
        end
      end
    end

    describe "#update_totals.fee_value" do
      subject { txn.fee_value }

      context "should return 0 if txn doesnt have fee" do
        let(:txn) { trade(date, '1 BTC', '2 LTC', '3 USD') }
        it { is_expected.to eq 0 }
      end

      context "should return fee amount when currency same as base" do
        let(:txn) { trade(date, '1 BTC', '2 LTC', nil, fee: '10 USD') }
        it { is_expected.to eq 10 }
      end

      context "should convert fee-worth" do
        let(:txn) { trade(date, '1 BTC', '10 USD', nil, fee: '1 EUR', fee_worth: '4 USD') }
        it { is_expected.to eq 4 }
      end

      context "should calc from net-value and to-amount when to-currency same as fee-currency" do
        let(:txn) { trade(date, '1 BTC', '2 LTC', '4 EUR', fee: '1 LTC') }
        it { is_expected.to eq 4 }
      end

      # this was causing NaN errors but it indicates a bigger problrm as to_amount should never be 0
      # if to_currency is set. we will let these errors continue.
      # context "when from or to amount are zero" do
      #   let(:txn) { trade(date, '1 BTC', '2 LTC', '4 EUR', fee: '1 LTC') }
      #   it "should not result in NaN or Infinity due to zero to_amount" do
      #     txn.to_amount = 0
      #     fee_val = txn.calculate_fee_value
      #     expect(fee_val).not_to eq Float::INFINITY
      #     expect(fee_val).not_to eq Float::NAN
      #   end
      #
      #   it "should not result in NaN or Infinity due to zero from_amount" do
      #     txn.from_amount = 0
      #     txn.from_currency_id = txn.fee_currency_id
      #     txn.to_amount = nil
      #     fee_val = txn.calculate_fee_value
      #     expect(fee_val).not_to eq Float::INFINITY
      #     expect(fee_val).not_to eq Float::NAN
      #   end
      # end

      context "should calc from net-value and from-amount when from-currency same as fee-currency" do
        let(:txn) { trade(date, '5 BTC', '10 LTC', '50 USD', fee: '1 BTC') }
        it { is_expected.to eq 10 }
      end

      context "should get market rate" do
        let(:txn) { trade(date, '1 BTC', '10 USD', nil, fee: '1 EUR') }
        it { is_expected.to eq 2 }
      end
    end
  end
end
