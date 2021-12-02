require 'rails_helper'

RSpec.describe IdexImporter, type: :importer do
  context "with negative balances fixed" do
    include_examples 'old api import', 'idex_importer', address: '0x8277fCe34eFba4e596E40Dde7E95c09C3c7B27CA'

    it 'should not result in negative balances' do
      VCR.use_cassette('idex_importer') do
        subject
        # this wallet had txns where user used funds from a partially completed order to initiate another order that would result in failed extractions but no negative balances. this was due to us using completed_at instead of started_at. it should have been fixed since.
        EntryBalanceUpdater.call(wallet.user)
        InvestmentsUpdater.call(wallet.user)
        expect(wallet.txns.where(negative_balances: true).count).to eq 0
        expect(wallet.user.investments.extraction_failed.count).to eq 0
      end
    end
  end
end
