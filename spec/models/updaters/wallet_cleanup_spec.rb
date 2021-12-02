require 'rails_helper'

RSpec.describe WalletCleanup, type: :model do
  let(:user) { create(:user) }
  let(:wallet) { create(:wallet, user: user) }
  let(:bnb) { create(:currency, symbol: 'BNB') }
  let(:btc) { create(:currency, symbol: 'BTC') }
  let(:txns) do
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-01 00:00 UTC', to_amount: 100, to_currency: btc)
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-02 00:00 UTC', to_amount: 100, to_currency: btc)
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-03 00:00 UTC', to_amount: 100, to_currency: btc)
    TxnBuilder::Deposit.create!(user, wallet, date: '2018-01-04 00:00 UTC', to_amount: 100, to_currency: bnb)
  end

  subject { described_class.call(user) }

  it 'should update balance of accounts' do
    txns
    user.accounts.update_all(balance: 0)
    subject
    expect(user.accounts.order(id: :asc).pluck(:balance)).to eq([300, 100])
  end

  context "deleting wallet" do
    let!(:btc) { create(:btc) }
    let(:wallet2) { create(:wallet, user: user) }

    around do |example|
      Sidekiq::Testing.inline! do
        example.run
      end
    end

    describe "gains should be properly calculated after a wallet is deleted" do
      before do
        deposit('2018-01-01', '1 BTC', '100 USD', wallet: wallet)
        withdraw('2018-01-02', '1 BTC', '200 USD', wallet: wallet2)
        InvestmentsUpdater.call(user)
      end

      it 'should result in gains and no extraction failures' do
        expect(user.investments.sum(:gain)).to eq 100.0
        expect(user.investments.extraction_failed.count).to eq 0

        wallet.destroy!
        InvestmentsUpdater.call(user)
        user.reload

        expect(user.investments.sum(:gain)).to eq 200
        expect(user.investments.extraction_failed.count).to eq 1
      end
    end
  end
end
