module Stubs
  def stub_current_employer
    let(:current_employer) { create(:employer) }
    before do
      request.headers['X-Auth-Token'] = current_employer.api_token
    end
  end

  def unstub_current_employer
    before do
      request.headers['X-Auth-Token'] = nil
    end
  end

  def stub_current_user
    let(:current_user) { create(:user) }
    before do
      request.headers['X-Auth-Token'] = current_user.api_token
    end
  end

  def unstub_current_user
    before do
      request.headers['X-Auth-Token'] = nil
    end
  end
end

RSpec.configure do |config|
  config.include Stubs
  config.extend Stubs
end
