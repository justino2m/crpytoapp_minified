require 'rails_helper'

RSpec.describe Subscription, type: :model do
  let(:user) { create(:user) }

  describe 'validations' do
    subject { build(:subscription) }

    it { should validate_presence_of :expires_at }
    it { should validate_presence_of :amount_paid }
    it { should validate_presence_of :max_txns }
    it { should validate_numericality_of(:max_txns).is_greater_than(0) }
    it { should be_valid }
  end
end
