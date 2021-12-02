require 'rails_helper'
require 'rack/test'

RSpec.describe Report, type: :model do
  let(:user) { create(:user, cost_basis_method: Investment::FIFO, realize_gains_on_exchange: true) }
  let(:wallet) { create(:wallet, user: user) }
  let(:wallet2) { create(:wallet, user: user) }
  let!(:btc) { create(:btc) }
  let!(:eth) { create(:eth) }
  let(:format) { 'csv' }

  context "with predefined data" do
    before do
      deposit('2018-01-01 01:00 UTC', '100 BTC', '100 USD', label: Transaction::AIRDROP)
      deposit('2018-01-01 01:10 UTC', '100 ETH', '100 USD')
      withdraw('2018-01-01 01:00 UTC', '1 BTC', '0.1 USD') # 0.9 USD loss
      ignored = withdraw('2018-01-01 01:30 UTC', '10 ETH', '200 USD') # no gain, should not be included in capital gains
      withdraw('2018-01-01 02:00 UTC', '1 ETH', '2 USD', label: Transaction::GIFT) # no gain
      withdraw('2019-01-01 03:00 UTC', '10 BTC', '1000 USD', label: Transaction::LOST) # no gain
      withdraw('2019-01-03 04:00 UTC', '10 ETH', '1000 USD') # 990 USD gain
      trade('2019-01-04 05:00 UTC', '10 BTC', '500 ETH', '2000 USD', fee: '2 BTC', fee_worth: '0.2 USD') # 1990 USD profit
      transfer('2019-01-05 06:00 UTC', '299 ETH', wallet2, fee: '1 ETH', fee_worth: '0.1 USD') # 0.9 USD loss
      withdraw('2019-01-06 07:00 UTC', '25 ETH', '50 USD', wallet: wallet2) # 25 USD profit
      ignored.ignore!
      InvestmentsUpdater.call(user)
      # note: to understand these txns run this query in byebug:
      # ap user.investments.order(date: :asc).where(currency: Currency.find_by(symbol: 'ETH')).map{ |x| [x.date, x.deposit?, x.amount.to_s, x.value.to_s, x.gain.to_s] }
      # byebug
    end

    describe CapitalGainsReport do
      it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
      it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    end

    # describe FullTaxReport do
    #   around { |example| Timecop.freeze(Time.utc(2020)) { example.run } }
    #   it { expect(generate(2018, :pdf)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019, :pdf)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    #
    #   context "with a country that doesnt have holding periods" do
    #     before do
    #       user.country = create(:country, code: 'SWE')
    #       user.save!
    #     end
    #
    #     it { expect(generate(2018, :pdf)).to match_snapshot('reports/2018_swe_' + described_class.to_s.underscore) }
    #     it { expect(generate(2019, :pdf)).to match_snapshot('reports/2019_swe_' + described_class.to_s.underscore) }
    #   end
    # end
    #
    # describe TurbotaxReport do
    #   it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    # end
    #
    # describe TurbotaxCdReport do
    #   before { allow_any_instance_of(described_class).to receive(:time_of_report) { Time.parse("2020-01-01 14:00") } }
    #   it { expect(generate(2018, :txf)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019, :txf)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    # end

    describe IrsReport do
      it { expect(generate(2018, :pdf)).to match_snapshot('reports/2018_' + described_class.to_s.underscore + '_pdf') }
      it { expect(generate(2019, :pdf)).to match_snapshot('reports/2019_' + described_class.to_s.underscore + '_pdf') }
    end

    describe SkatteverketK4Report do
      let(:format) { 'xls' }
      it { expect(generate(2018, :pdf)).to match_snapshot('reports/2018_' + described_class.to_s.underscore + '_pdf') }
      it { expect(generate(2019, :pdf)).to match_snapshot('reports/2019_' + described_class.to_s.underscore + '_pdf') }
    end

    # describe SpecialTxnsReport do
    #   it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    # end

    # describe IncomeReport do
    #   it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    # end
    #
    # describe ExpenseReport do
    #   it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    # end

    describe TransactionsReport do
      it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
      it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    end

    # describe EndOfYearHoldingsReport do
    #   let(:format) { 'xls' }
    #   it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #   it { expect(generate(2019)).to match_snapshot('reports/2019_' + described_class.to_s.underscore) }
    # end
    #
    # describe SwissValuationReport do
    #   let(:format) { 'xls' }
    #   let!(:chf) { create(:currency, symbol: 'CHF', fiat: true) }
    #   let!(:xyz) { create(:currency, symbol: 'XYZ', fiat: false) }
    #   before { deposit('2018-01-05 01:20 UTC', '5 XYZ', '50 USD') }
    #   it { expect(generate(2018)).to match_snapshot('reports/2018_' + described_class.to_s.underscore) }
    #
    #   it "should not be valid" do
    #     report = described_class.new(user: user, format: format)
    #     report.from = DateTime.parse('2015-01-01')
    #     expect(report).not_to be_valid
    #     expect(report.errors.messages[:base]).to include('Report can only be generated for these years: 2017, 2018')
    #   end
    # end
  end

  def generate(year, fmt=:csv)
    klass = described_class.new(user: user, format: fmt)
    klass.year = year
    expect(klass).to be_valid
    if fmt == :pdf
      PDF::Inspector::Text.analyze(klass.to_pdf(klass.prepare_report(klass.generate))).strings
    else
      klass.prepare_report(klass.generate)
    end
  end

  def import_csv(file_name)
    spreadsheet = Roo::Spreadsheet.open(file_fixture(file_name), extension: 'csv')

    CsvImport.create!(
      user: user,
      wallet: wallet,
      file: Rack::Test::UploadedFile.new(file_fixture(file_name)),
      initial_rows: spreadsheet.each.take(20)
    )
  end

  def to_dec(number)
    @report ||= Report.new
    @report.send(:to_dec, number)
  end
end
