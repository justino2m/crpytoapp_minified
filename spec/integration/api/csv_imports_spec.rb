require "rails_helper"

describe "Csv Imports", type: :request do
  let(:current_user) { create(:user) }
  let(:wallet) { create(:wallet, user: current_user) }
  let!(:btc) { create(:btc) }

  around do |example|
    Sidekiq::Testing.inline!{ example.run }
  end

  before do
    allow(UpdateUserStatsWorker).to receive :perform_later
  end

  context 'custom' do
    it_behaves_like 'csv import', 'sample.csv'
  end

  context "abra" do
    it_behaves_like 'csv import', 'abra_14TDVKS_Transaction_History_2018_(1).csv'
  end

  context "anxpro" do
    it_behaves_like 'csv import', 'anxpro-transaction_report.csv'
  end

  context "zelcore" do
    it_behaves_like 'csv import', 'XZC_transactions_Bawler-zelcore.csv'
  end

  context "coindeal" do
    it_behaves_like 'csv import', 'coindeal-My_transactions.csv'
  end

  context "polonidex" do
    # this file was created manually from the polonidex order history page
    it_behaves_like 'csv import', 'polonidex-copypaste.csv'
  end
end
