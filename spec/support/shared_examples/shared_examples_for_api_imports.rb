RSpec.shared_examples "api import" do |name, options|
  let(:wallet) { create(:wallet, (try(:wallet_options) || {}).merge(api_connected: true)) }
  let(:klass) { described_class.new(wallet, options.symbolize_keys) }
  subject { klass.process }

  before do
    allow_any_instance_of(TxnBuilder::Adapter).to receive(:find_currency_by_symbol) do |instance, tag, symbol|
      next if tag == SymbolAlias::TOKEN_ADDRESS_TAG
      allow(Rollbar).to receive(:debug)
      Currency.crypto.where(symbol: symbol).first_or_create!(name: symbol)
    end
  end

  it "should import from #{name}" do
    # note: allowing repeatable playback causes issues with post requests as
    # vcr ignores the request bodies
    VCR.use_cassette(name) do
      if options[:error].present?
        expect { subject }.to raise_error(options[:error].class, options[:error].message)
      else
        subject
        # TradeMatcher.call(wallet.user) if options[:match_trades]
        unless options[:no_repeat]
          Timecop.travel(Time.now + 1.second) do
            if options[:old_api_spec]
              # we were also storing the balances in an instance variable and reusing the instance
              klass.adapter.initialized_at = Time.now
              allow(klass).to receive(:sync_balances) { wallet.api_syncdata[:balances] }
              repeater = klass
            else
              repeater = described_class.new(wallet, options.symbolize_keys)
            end
            expect { repeater.process }.not_to change { Entry.count }
          end
        end
        wallet_snapshot = generate_wallet_snapshot(wallet)
        expect(wallet_snapshot).to match_snapshot('api_imports/' + name)
      end
    end
  end
end

# old api imports are missing a second call to the balances api (due to it being saved on instance var)
RSpec.shared_examples "old api import" do |name, options|
  include_examples "api import", name, options.merge(old_api_spec: true)
end