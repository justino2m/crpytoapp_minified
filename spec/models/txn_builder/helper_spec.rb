require 'rails_helper'

RSpec.describe TxnBuilder::Helper do
  describe "#determine_date_format" do
    it 'should determine correct format' do
      expect(described_class.determine_date_format(['1-1-2019 14:52'])).to eq nil # nil means regular strptime will work
      expect(described_class.determine_date_format(['1-1-2019 14:52:23', '1-14-2019 15:00:00'])).to eq '%m-%d-%Y %H:%M:%S'
      expect(described_class.determine_date_format(['1-1-2019 2:52 PM', '14-1-2019 3:00 PM'])).to eq nil
      expect(described_class.determine_date_format(['1-1-2019, 2:52 PM', '14-1-2019 3:00 PM'])).to eq nil
      expect(described_class.determine_date_format(['1/1/2019'])).to eq '%m/%d/%Y' # slash separator is commonly used in the US
      expect(described_class.determine_date_format(['1-1-2019'])).to eq nil
      expect(described_class.determine_date_format(['1.1.2019'])).to eq nil
      expect(described_class.determine_date_format(['1/1/2019', '2/20/2019'])).to eq '%m/%d/%Y'
      expect(described_class.determine_date_format(['1.1.2019', '2.20.2019'])).to eq '%m.%d.%Y'
    end

    context "with year clash" do
      it 'should determine correct format' do
        expect(described_class.determine_date_format(['16-10-16'])).to eq '%d-%m-%y'
        expect(described_class.determine_date_format(['16-10-16', '25-10-16'])).to eq '%d-%m-%y'
        expect(described_class.determine_date_format(['16-10-16', '16-10-25'])).to eq '%y-%m-%d'
      end
    end

    context "with month clash" do
      it 'should determine correct format' do
        expect(described_class.determine_date_format(['10-10-16'])).to eq '%d-%m-%y'
        expect(described_class.determine_date_format(['10-10-16', '25-10-16'])).to eq '%d-%m-%y'
        expect(described_class.determine_date_format(['10-10-16', '10-25-16'])).to eq '%m-%d-%y'
      end
    end

    context "with non-american date" do
      it 'should determine correct format' do
        expect(described_class.determine_date_format(['1/1/2019'], false)).to be nil
        expect(described_class.determine_date_format(['1/1/2019'], true)).to eq '%m/%d/%Y'
      end
    end
  end

  describe "#split_pair" do
    it 'should split all variations of separators' do
      expect(described_class.split_pair('BTC_ETH')).to eq ['BTC', 'ETH']
      expect(described_class.split_pair('BTC/ETH')).to eq ['BTC', 'ETH']
      expect(described_class.split_pair('BTC-ETH')).to eq ['BTC', 'ETH']
      expect(described_class.split_pair('BTC_OLD/ETH')).to eq ['BTC', 'ETH']
    end
  end
end
