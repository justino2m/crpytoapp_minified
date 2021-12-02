require 'rails_helper'

RSpec.describe InvestmentsUpdater, type: :model do
  # 'user' is declared by the shared examples
  let!(:wallet) { create(:wallet, user: user) }
  let!(:wallet2) { create(:wallet, user: user) }
  let!(:btc) { create(:btc) }
  let!(:eth) { create(:eth) }
  let!(:bnb) { create(:bnb) }
  let!(:xlm) { create(:currency, symbol: 'XLM', name: 'XLM', fiat: false) }

  subject do
    described_class.call(user)
    # ensure investments dont change unnecessarily
    expect { described_class.call(user) }.not_to change{ Investment.order(id: :desc).first.id }
    # delete transfers to mimic editing/deleting (this was the cause of a major bug)
    Transaction.transfers.update_all(gain: nil)
    described_class.call(user)
  end

  context "with normal trades" do
    before do
      deposit('2017-01-01 00:00 UTC', '3 BTC', '30 USD')
      deposit('2018-01-02 01:10 UTC', '3 BTC', '300 USD')
      deposit('2018-01-02 02:00 UTC', '4 BTC', '4000 USD')
      withdraw('2018-01-02 03:00 UTC', '5 BTC', '1000 USD')
      trade('2018-01-02 04:00 UTC', '5 BTC', '500 ETH', '2000 USD')
      transfer('2018-01-02 04:00 UTC', '300 ETH', wallet2)
      withdraw('2018-01-02 05:00 UTC', '250 ETH', '500 USD', wallet: wallet2)
    end

    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'lifo'
    it_behaves_like 'acb'
  end

  context "with missing deposits" do
    before do
      deposit('2018-01-02 01:00 UTC', '1 BTC', '100 USD')
      trade('2018-01-02 04:00 UTC', '5 BTC', '500 ETH', '2000 USD')
      transfer('2018-01-02 04:00 UTC', '300 ETH', wallet2)
      withdraw('2018-01-02 05:00 UTC', '250 ETH', '500 USD', wallet: wallet2)
    end

    it_behaves_like 'fifo', true
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'lifo'
    it_behaves_like 'acb'
  end

  context "with txns on same date" do
    before do
      # 4480 - 1050, we order by amount in asc order                                Value       Gain
      deposit('2017-12-31 00:00 UTC', '1 BTC', '100 USD')                         # 100         0

      deposit('2018-01-01 00:00 UTC', '3 BTC', '30 USD')  # ---                     30          0
      withdraw('2018-01-01 00:00 UTC', '5 BTC', '1000 USD')
      deposit('2018-01-01 00:00 UTC', '3 BTC', '330 USD') # ---                     330
      deposit('2018-01-01 00:00 UTC', '4 BTC', '4000 USD')  #                       4000
      withdraw('2018-01-01 00:00 UTC', '1 BTC', '50 USD') #

      deposit('2018-01-02 00:00 UTC', '2 BTC', '22 USD')
      trade('2018-01-02 00:00 UTC', '5 BTC', '500 ETH', '2000 USD')
      transfer('2018-01-02 00:00 UTC', '300 ETH', wallet2)
      withdraw('2018-01-02 00:00 UTC', '250 ETH', '500 USD', wallet: wallet2)
    end

    # note: withdrawals at same time are sorted by id only (not by amount).
    it_behaves_like 'fifo'
    it_behaves_like 'fifo', true
    it_behaves_like 'fifo_ireland', true
    it_behaves_like 'lifo' # same-time withdrawals are sorted in same way as fifo
    it_behaves_like 'acb'
  end

  context "with fees" do
    before do
      deposit('2018-01-01 00:00 UTC', '50 USD')
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-01-01 00:00 UTC', '50 BNB', '250 USD')

      trade('2018-01-02 00:00 UTC', '5 BTC', '100 ETH', '2000 USD', fee: '10 USD')
      trade('2018-01-03 00:00 UTC', '10 ETH', '2 BTC', '2000 USD', fee: '20 BNB') # fee in diff. currency
      trade('2018-01-03 01:00 UTC', '20 ETH', '500 XLM', '500 USD', fee: '5 XLM') # fee in same currency with no prior deposits
      transfer('2018-01-04 00:00 UTC', '300 ETH', wallet2, fee: '10 ETH')
    end

    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'lifo'
    it_behaves_like 'acb'
  end

  context "when some txns are inserted afterwards" do
    let(:deposit1) { deposit('2018-01-02 00:00 UTC', '8 BTC', '880 USD') }
    let(:deposit2) { deposit('2018-01-04 00:00 UTC', '200 ETH', '600 USD') }

    before do
      deposit('2018-01-01 00:00 UTC', '10 BTC', '100 USD')
      withdraw('2018-01-01 01:00 UTC', '5 BTC', '1000 USD')

      # deposit1 --- added afterwards
      # deposit('2018-01-02 00:00 UTC', '8 BTC', '880 USD')

      deposit('2018-01-03 01:00 UTC', '10 BTC', '400 USD')
      withdraw('2018-01-03 02:00 UTC', '10 BTC', '1000 USD')

      # deposit2 --- added afterwards
      # deposit('2018-01-04 00:00 UTC', '200 ETH', '600 USD')

      trade('2018-01-05 01:00 UTC', '5 BTC', '100 ETH', '2000 USD')
      trade('2018-01-05 02:00 UTC', '10 ETH', '2 BTC', '200 USD')
      transfer('2018-01-05 03:00 UTC', '250 ETH', wallet2) # should not result in any investment
      withdraw('2018-01-05 04:00 UTC', '2 BTC', '10 USD')
    end

    context "adding the deposits" do
      before do
        described_class.call(user)
        deposit1
        deposit2
      end

      # note: we are adding a 10 BTC and a 200 ETH deposit.
      it_behaves_like 'fifo'
      it_behaves_like 'fifo_ireland'
      it_behaves_like 'lifo'
      it_behaves_like 'acb'
    end

    # sanity checks before we add the other deposits
    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'lifo'
    it_behaves_like 'acb'
  end

  context "with normal wash sale: buy, sell" do
    before do
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      withdraw('2018-11-01 00:00 UTC', '10 BTC', '500 USD')
      deposit('2018-11-10 00:00 UTC', '10 BTC', '750 USD')
      withdraw('2018-12-20 00:00 UTC', '10 BTC', '1000 USD')
    end

    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'acb_canada'
    it_behaves_like 'shared_pool'

    context "txns" do
      let(:user) { create(:user, cost_basis_method: Investment::ACB_CANADA, realize_gains_on_exchange: false) }

      it 'should also have updated the withdrawal txns cost basis' do
        subject
        gains = user.txns.ordered.pluck(:gain)
        expect(gains).to eq [0, 0, 0, -250] # same as the gains in the acb_canada geenrated file
      end
    end
  end

  context "with advance wash sale: buy, buy in advance, sell" do
    before do
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')

      deposit('2018-11-01 00:00 UTC', '5 BTC', '50 USD')
      deposit('2018-11-02 00:00 UTC', '10 BTC', '200 USD')
      withdraw('2018-11-10 00:00 UTC', '6 BTC', '500 USD')
      withdraw('2018-11-11 00:00 UTC', '2 BTC', '500 USD')

      withdraw('2018-11-25 00:00 UTC', '10 BTC', '2000 USD')
    end

    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'acb_canada'
    it_behaves_like 'shared_pool' # no wash sales in this case
  end

  context "with wash sale: split over multiple pools" do
    before do
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')

      deposit('2018-11-01 00:00 UTC', '5 BTC', '50 USD')
      deposit('2018-11-02 00:00 UTC', '10 BTC', '200 USD')
      withdraw('2018-11-10 00:00 UTC', '10 BTC', '500 USD')
      withdraw('2018-11-11 00:00 UTC', '10 BTC', '500 USD')

      withdraw('2018-12-20 00:00 UTC', '5 BTC', '2000 USD')
    end

    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'acb_canada'
    it_behaves_like 'shared_pool'
  end

  context "when a wash-sale deposit is added/deleted" do
    # it should return the extracted gains back to original withdrawals!

    before do
      deposit('2018-01-01 00:00 UTC', '5 BTC', '5000 USD')
      withdraw('2018-01-02 00:00 UTC', '1 BTC', '100 USD')
      withdraw('2018-01-03 00:00 UTC', '1 BTC', '200 USD')
    end

    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'acb_canada'
    it_behaves_like 'shared_pool'

    context "after adding the deposit" do
      let(:dep) { deposit('2018-01-04 00:00 UTC', '2 BTC', '4000 USD') }

      before do
        described_class.call(user)
        dep
      end

      it_behaves_like 'fifo'
      it_behaves_like 'acb_canada'
      it_behaves_like 'fifo_ireland'
      it_behaves_like 'shared_pool'

      context "and deleting it" do
        before do
          described_class.call(user)
          dep.destroy!
        end

        it_behaves_like 'fifo'
        it_behaves_like 'fifo_ireland'
        it_behaves_like 'acb_canada'
        it_behaves_like 'shared_pool'
      end
    end
  end

  context "with wash sale and fee" do
    before do
      # if wash sale rules are applied before the crypto fees have been added to the deposit then wash sale rule wont take the fee into account
      # need to fix this by running the rules at the end of create_investment!
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')         # BTC +1000
      deposit('2018-01-01 00:00 UTC', '10 ETH', '10000 USD')        # ETH +10,000
      withdraw('2018-01-20 00:00 UTC', '5 BTC', '10000 USD')        # BTC -500 value, +9500 gain

      trade('2018-01-22 00:00 UTC', '5 ETH', '1 BTC', '1000 USD', fee: '0.5 BTC') # ETH -5000 (-4000 gain), BTC +1000, fee: -50
      # withdraw('2018-01-22 00:00 UTC', '5 ETH', '1000 USD')
      # deposit('2018-01-22 00:00 UTC', '1 BTC', '1000 USD')
      # withdraw('2018-01-22 00:00 UTC', '0.5 BTC', '500 USD')

      withdraw('2018-01-23 00:00 UTC', '5.5 BTC', '500 USD')

      deposit('2018-01-24 00:00 UTC', '3 ETH', '600 USD')           # ETH +600
    end

    # with trade instead of separate txs
    it_behaves_like 'fifo_ireland', true
    it_behaves_like 'acb_canada', true
    it_behaves_like 'shared_pool', true
  end

  context "with shared pooling" do
    let(:user) { create(:user, cost_basis_method: Investment::SHARED_POOL, realize_gains_on_exchange: true) }

    it 'should commit investments before finalizing' do |ex|
      # this caused a bug where initial deposits had 0 gain on txn because the investments
      # were not persisted before the gains were updated on the txn
      deposit('2018-01-01 00:00 UTC', '1 BTC', '100 USD')
      deposit('2018-01-01 00:00 UTC', '2 BTC', '400 USD')
      described_class.call(user)
      compare_investments(self, ex)
      expect(user.txns.ordered.pluck(:to_cost_basis)).to eq [400, 100]
    end

    it 'should handle cases where multiple withdrawals occur in 30 day pool' do |ex|
      deposit('2018-01-01 00:00 UTC', '3 BTC', '300 USD')
      withdraw('2018-01-02 00:00 UTC', '1 BTC', '200 USD')
      withdraw('2018-01-03 00:00 UTC', '1 BTC', '10 USD')
      deposit('2018-01-04 00:00 UTC', '1 BTC', '400 USD')
      withdraw('2018-01-04 00:00 UTC', '1 BTC', '1000 USD')
      withdraw('2018-01-05 00:00 UTC', '1 BTC', '50 USD')
      described_class.call(user)
      compare_investments(self, ex)
    end

    it 'should correctly handle same day deposits' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      withdraw('2018-01-20 05:00 UTC', '8 BTC', '8000 USD')
      described_class.call(user)
      compare_investments(self, ex)

      dep1 = deposit('2018-01-20 04:00 UTC', '5 BTC', '10000 USD')
      described_class.call(user)
      compare_investments(self, ex, 'second')

      dep2 = deposit('2018-01-20 08:00 UTC', '2 BTC', '6000 USD')
      described_class.call(user)
      compare_investments(self, ex, 'third')

      dep1.destroy!
      described_class.call(user)
      compare_investments(self, ex, 'forth')

      dep2.destroy!
      described_class.call(user)
      compare_investments(self, ex, 'last')
    end

    it 'should correctly handle 30 day deposits' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      withdraw('2018-01-20 05:00 UTC', '8 BTC', '8000 USD')
      described_class.call(user)
      compare_investments(self, ex)

      dep1 = deposit('2018-01-20 04:00 UTC', '5 BTC', '10000 USD')
      described_class.call(user)
      compare_investments(self, ex, 'second')

      dep2 = deposit('2018-02-05 08:00 UTC', '2 BTC', '6000 USD')
      described_class.call(user)
      compare_investments(self, ex, 'third')

      deposit('2018-02-25 08:00 UTC', '2 BTC', '20000 USD')
      described_class.call(user)
      compare_investments(self, ex, 'forth')

      dep1.destroy!
      described_class.call(user)
      compare_investments(self, ex, 'fifth')

      dep2.destroy!
      described_class.call(user)
      compare_investments(self, ex, 'last')
    end

    it 'should handle mixed pool deletions' do |ex|
      deposit('2017-11-01 00:00 UTC', '4 ETH', '40 USD')
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-01-01 00:00 UTC', '3 ETH', '1500 USD')
      withdraw('2018-01-01 01:00 UTC', '10 ETH', '5000 USD')
      deposit('2018-01-01 10:00 UTC', '3 ETH', '3000 USD')
      transfer('2018-01-02 00:00 UTC', '1 BTC', wallet2)

      tr1 = trade('2018-01-02 00:00 UTC', '5 BTC', '1 ETH', '8000 USD')

      trade('2018-01-02 05:00 UTC', '5 BTC', '4 ETH', '8000 USD')

      transfer('2018-01-03 00:00 UTC', '1 BTC', wallet, wallet: wallet2)
      dep1 = deposit('2018-01-03 00:00 UTC', '3 ETH', '2000 USD')
      deposit('2018-01-03 00:00 UTC', '5 BTC', '10000 USD')
      trade('2018-01-04 00:00 UTC', '10 ETH', '20 BTC', '8000 USD')

      described_class.call(user)
      compare_investments(self, ex)

      tr1.destroy!
      dep1.destroy!
      described_class.call(user)
      compare_investments(self, ex, 'last')
    end

    it 'should differentiate between different calls to create_withdrawal' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-02-01 00:00 UTC', '3 BTC', '1000 USD')
      trade('2018-02-01 01:00 UTC', '5 BTC', '10 ETH', '10000 USD', fee: '1 BTC')
      described_class.call(user)
      compare_investments(self, ex)
    end

    it 'should not use 30 day pool for fees if its depleted' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-02-01 00:00 UTC', '3 BTC', '1000 USD')
      trade('2018-02-01 01:00 UTC', '10 BTC', '10 ETH', '10000 USD', fee: '1 BTC')
      deposit('2018-02-05 00:00 UTC', '2 BTC', '1000 USD')
      described_class.call(user)
      compare_investments(self, ex)
    end

    it 'should not use 30 day pool if the deposit txn has been used up by a same day txn' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-02-01 00:00 UTC', '3 BTC', '1000 USD')
      trade('2018-02-01 01:00 UTC', '10 BTC', '10 ETH', '10000 USD', fee: '1 BTC')
      deposit('2018-02-05 00:00 UTC', '2 BTC', '1000 USD')
      withdraw('2018-02-05 01:00 UTC', '2 BTC', '500 USD')
      described_class.call(user)
      compare_investments(self, ex)
    end

    it 'should not use 30 day pool if the deposit txn has been used up by a newer txn' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-02-01 00:00 UTC', '3 BTC', '1000 USD')
      trade('2018-02-01 01:00 UTC', '10 BTC', '10 ETH', '10000 USD', fee: '1 BTC')
      deposit('2018-02-05 00:00 UTC', '2 BTC', '1000 USD')
      withdraw('2018-02-05 01:00 UTC', '3 BTC', '500 USD')
      deposit('2018-02-20 00:00 UTC', '1 BTC', '1000 USD')
      described_class.call(user)
      compare_investments(self, ex)
    end

    it 'should not use 30 day pool txns that were depleted by earlier withdrawal' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      deposit('2018-02-01 00:00 UTC', '3 BTC', '1000 USD')
      trade('2018-02-01 01:00 UTC', '10 BTC', '10 ETH', '10000 USD', fee: '1 BTC')
      withdraw('2018-02-03 01:00 UTC', '3 BTC', '500 USD')
      deposit('2018-02-05 00:00 UTC', '2 BTC', '1000 USD')
      described_class.call(user)
      compare_investments(self, ex)
    end

    it 'should create realized loss only once' do |ex|
      deposit('2018-01-01 00:00 UTC', '10 BTC', '1000 USD')
      trade('2018-02-01 01:00 UTC', '2 BTC', '10 ETH', '10000 USD', fee: '1 BTC')
      withdraw('2018-02-03 01:00 UTC', '4 BTC', '500 USD', label: Transaction::REALIZED_GAIN)
      deposit('2018-02-05 00:00 UTC', '2 BTC', '1000 USD')
      described_class.call(user)
      compare_investments(self, ex)
    end
  end

  context "with transfer fees" do
    let(:remaining_amount) { Investment.deposits.sum(:amount) + Investment.withdrawals.sum(:amount) }
    let(:remaining_value) { Investment.deposits.sum(:value) - Investment.withdrawals.sum(:value) }
    let(:gains) { Investment.withdrawals.sum(:gain) }

    before do
      deposit('2018-01-01 00:00 UTC', '10 BTC', '10000 USD')
      transfer('2018-01-02 00:00 UTC', '9 BTC', wallet2, fee: '1 BTC')
      withdraw('2018-01-03 00:00 UTC', '9 BTC', '20000 USD', wallet: wallet2)
      subject
    end

    context "fifo" do
      let(:user) { create(:user, cost_basis_method: Investment::FIFO) }
      it 'should not have any remaining investments' do
        expect(remaining_amount).to eq 0
        expect(remaining_value).to eq 0
        expect(gains).to eq 10000
      end
    end

    context "acb" do
      let(:user) { create(:user, cost_basis_method: Investment::AVERAGE_COST) }
      it 'should not have any remaining investments' do
        expect(remaining_amount).to eq 0
        expect(remaining_value).to eq 0
        expect(gains).to eq 10000
      end
    end

    context "fifo_ireland" do
      let(:user) { create(:user, cost_basis_method: Investment::FIFO_IRELAND) }
      it 'should not have any remaining investments' do
        expect(remaining_amount).to eq 0
        expect(remaining_value).to eq 0
        expect(gains).to eq 10000
      end
    end
  end

  context "with realized p&l txns" do
    before do
      deposit('2018-01-01 00:00 UTC', '1 BTC', '30 USD')
      deposit('2018-01-02 00:00 UTC', '300 USD', '300 USD', label: Transaction::REALIZED_GAIN)
      withdraw('2018-01-02 01:00 UTC', '300 USD', '300 USD', label: Transaction::REALIZED_GAIN)
      withdraw('2018-01-03 00:00 UTC', '0.5 BTC', '1000 USD', label: Transaction::REALIZED_GAIN)
      deposit('2018-01-03 01:00 UTC', '0.5 BTC', '1000 USD', label: Transaction::REALIZED_GAIN)
      withdraw('2018-01-04 00:00 UTC', '1 BTC', '1000 USD')
      withdraw('2018-01-04 00:00 UTC', '0.5 BTC', '20 USD')
    end

    # note: when you realize a gain on crypto, the net value is a complete loss followed by another gain event
    # for the actual crypto
    it_behaves_like 'fifo'
    it_behaves_like 'fifo_ireland'
    it_behaves_like 'lifo'
    it_behaves_like 'acb'
  end

  context "with bugs that resulted in 0 gains when fee_value was 0" do
    before do
      user.realize_transfer_fees = true
      user.save!

      deposit('2018-01-01 00:00 UTC', '1 BTC', '30 USD')
      transfer('2018-01-02 04:00 UTC', '0.5 BTC', wallet2, fee: '0.1 BTC', fee_worth: '0 USD')
    end

    it_behaves_like 'fifo'
  end

  # this is not really a spec but a demonstration of how we can get missing cost basis without negative txns
  context "with transfers that result in missing cost basis but no negative txn" do
    let(:user) { create(:user, cost_basis_method: Investment::FIFO, realize_gains_on_exchange: true, account_based_cost_basis: true) }
    let!(:wallet3) { create(:wallet, user: user) }

    before do
      # missing cost basis can happen without negative balances when user transfers funds from
      # wallet A to wallet B and then transfers those funds from wallet B to wallet C but all happen
      # at the same timestamp and the second transfer txn has an ID lower than the first one (meaning
      # that it gets parsed first by the investment calculator)

      # these txns simply ensure there are no negative balances due to the transfers
      deposit('2018-01-01 00:00 UTC', '0.5 BTC', '100 USD', wallet: wallet2)
      deposit('2018-01-01 00:00 UTC', '1 BTC', '100 USD')

      # this is the second transfer
      withdraw('2018-01-02 00:00 UTC', '1.5 BTC', '50 USD', wallet: wallet2)
      deposit('2018-01-02 00:00 UTC', '1.5 BTC', '25 USD', wallet: wallet3)

      # this is the first transfer
      deposit('2018-01-02 00:00 UTC', '1 BTC', '25 USD', wallet: wallet2)
      withdraw('2018-01-02 00:00 UTC', '1 BTC', '50 USD')

    end

    it 'should result in missing cost basis' do
      UpdateUserStatsWorker.perform_now(user.id)
      expect(user.txns.transfers.count).to eq 2
      expect(user.txns.where(negative_balances: false).where('missing_cost_basis > 0').count).to eq 1
    end
  end

  #  UPDATE: this has been fixed with the transaction type ordering in the txn ordered scope
  # and should no longer result in missing cost basis
  context "with trade that results in missing cost basis but no negative txn" do
    let(:user) { create(:user, cost_basis_method: Investment::FIFO, realize_gains_on_exchange: true) }
    let!(:wallet3) { create(:wallet, user: user) }

    before do
      # missing cost basis can happen without negative balances when user carries out a trade
      # with coins received at same time as the trade but the deposit is added after the trade
      # and the deposit currency id is higher than trade to_currency_id
      create(:eth)
      create(:currency, symbol: 'XYZ')
      trade('2018-01-01 00:00 UTC', '0.5 XYZ', '500 ETH', '2000 USD')
      deposit('2018-01-01 00:00 UTC', '0.5 XYZ', '100 USD')
    end

    it 'should not result in missing cost basis' do
      UpdateUserStatsWorker.perform_now(user.id)
      expect(user.txns.where(negative_balances: false).where('missing_cost_basis > 0').count).to eq 0
    end
  end

  context "with wallet-based cost basis" do
    context "and transfer txn" do
      context "with wash sale" do
        let(:country) { create(:country, code: 'SWE')}
        let(:user) { create(:user, cost_basis_method: Investment::FIFO_IRELAND, realize_gains_on_exchange: true, account_based_cost_basis: true, country: country) }

        before do
          deposit('2018-01-01 00:00 UTC', '5 BTC', '1000 USD')
          deposit('2018-01-02 00:00 UTC', '10 BTC', '1000 USD')
          transfer('2018-01-03 00:00 UTC', '12 BTC', wallet2)
        end

        it 'should not cause wash sales' do
          subject
          compare_investments(self)
        end
      end

      context "with long term" do
        let(:user) { create(:user, cost_basis_method: Investment::FIFO, realize_gains_on_exchange: true, account_based_cost_basis: true) }

        before do
          deposit('2018-01-01 00:00 UTC', '5 BTC', '1000 USD')
          deposit('2018-05-01 00:00 UTC', '10 BTC', '1000 USD')
          transfer('2018-06-01 00:00 UTC', '12 BTC', wallet2)
          withdraw('2019-02-01 00:00 UTC', '12 BTC', '20000 USD', wallet: wallet2)
        end

        it 'should carry over initial cost basis' do
          subject
          with1, with2  = Investment.withdrawals.where('gain > 0').order(amount: :desc).all
          expect(with1.amount).to eq -5
          expect(with1.from_date).to eq '2018-01-01 00:00 UTC'.to_datetime # this should be date of original deposit
          expect(with1.from.date).to eq '2018-06-01 00:00 UTC'.to_datetime # this is the transfer date
          expect(with1.long_term).to eq true
          expect(with2.amount).to eq -7
          expect(with2.from.date).to eq '2018-06-01 00:00 UTC'.to_datetime
          expect(with2.from_date).to eq '2018-05-01 00:00 UTC'.to_datetime
          expect(with2.long_term).to eq false
        end
      end

    end
  end
end
