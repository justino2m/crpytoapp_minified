require 'rails_helper'

RSpec.describe HitbtcImporter, type: :importer do
  it_behaves_like 'old api import', 'hitbtc_importer', api_key: 'xxx', api_secret: 'xxx'
end
