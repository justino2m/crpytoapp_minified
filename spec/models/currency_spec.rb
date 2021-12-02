require 'rails_helper'

RSpec.describe Currency, type: :model do
  let(:eth) { create(:eth) }

  describe "#tokens" do
    let!(:child1) { eth.tokens.create!(name: 'Child1', symbol: 'X') }
    let!(:child2) { eth.tokens.create!(name: 'Child2', symbol: 'X2', token_address: '123') }

    it 'should have tokens' do
      expect(eth.tokens.count).to eq 2
      expect(eth.tokens.where(token_address: '123').count).to eq 1
    end
  end
end
