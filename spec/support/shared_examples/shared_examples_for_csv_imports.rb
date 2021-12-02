# when importing fails due to an issue in controller
RSpec.shared_examples "bad csv import" do |file_name, error|
  subject { api_import_csv(wallet, file_name) }

  it "should fail to import #{file_name}" do
    expect(subject).to be_successful
    json = api_fetch_csv_status # have to reload since first call will return pending state
    expect(json['state'].to_sym).to be_in(CsvImport::FAILED_STATES)
    expect(json['error']).to eq error
  end
end

# when it detects multiple mappers
RSpec.shared_examples "multi csv import" do |file_name, *mappings|
  subject { api_import_csv(wallet, file_name) }

  it "should fail to import #{file_name}" do
    expect(subject).to be_successful
    json = api_fetch_csv_status
    expect(json['potential_mappers'].sort).to eq mappings.sort
  end
end

RSpec.shared_examples "csv import" do |file_name, options = {}, &csv_fetcher|
  let(:csv) { csv_fetcher ? csv_fetcher.call : file_name }
  subject { api_import_csv(wallet, csv, options) }

  before do
    allow_any_instance_of(TxnBuilder::Adapter).to receive(:find_currency_by_symbol) do |instance, tag, symbol|
      next if tag == SymbolAlias::TOKEN_ADDRESS_TAG
      Currency.crypto.where(symbol: symbol).first_or_create!(name: symbol)
    end
  end

  it("should import from #{file_name}", options[:slow] ? { slow: true } : { fast: true }) do
    expect(JSON.parse(subject.body)).to eq({}) unless subject.successful? # just for printing sth meaningful
    expect(subject).to be_successful

    # we need to sort again with ruby due to conflicts between postgres sorting on mac vs linus (known issue with pg)
    snapshots = Wallet.all.map { |w| generate_wallet_snapshot(w) }.sort_by { |x| [x[:name], x[:txn_count], x[:entry_count]] }
    csv_import = CsvImport.last
    expect(csv_import.error).to eq nil
    if csv_import.state == "unknown_csv"
      raise "No mapper matched these headers: #{csv_import.initial_rows[0].join(', ')}"
    end
    expect(csv_import.state).to eq 'completed'
    if csv_import.mapping_id.nil?
      # this will show multiple mappers
      expect(csv_import.potential_mappers.keys).to eq [csv_import.mapping_id]
    end

    # this could indicate that you are using the order_id as external_id which causes a strict duplicate check
    # use txhash instead if the same hash in the file can have multiple entries
    expect(csv_import.duplicate_count).to eq 0 unless options[:allow_duplicates]

    wallet_snapshot = snapshots.count == 1 ? snapshots[0] : { wallets: snapshots }
    wallet_snapshot[:csv_import] = csv_import.results.except('errors', 'skipped')
    expect(wallet_snapshot).to match_snapshot('csv_imports/' + file_name)

    # ap print_entries(wallet, 'ZEUR')

    # ensure it doesnt reimport duplicates
    unless options[:slow]
      Timecop.travel(Time.now + 5.seconds) do
        expect { api_import_csv(wallet, csv, options) }.not_to change { Entry.count }
      end
      second_csv_import = CsvImport.last
      expect(second_csv_import.success_count).to eq 0
      expect(second_csv_import.skipped_count + second_csv_import.duplicate_count).to eq(csv_import.success_count + csv_import.skipped_count + csv_import.duplicate_count)
      expect(second_csv_import.error_count).to eq csv_import.error_count
    end
  end
end

RSpec.shared_examples "grouped csv import" do |id, *file_names|
  before do
    allow_any_instance_of(TxnBuilder::Adapter).to receive(:find_currency_by_symbol) do |instance, tag, symbol|
      Currency.crypto.where(symbol: symbol).first_or_create!(name: symbol)
    end
  end

  it "should import from #{file_names.join(', ')}" do
    file_names.map.with_index do |name, idx|
      Timecop.travel(Time.now + idx.seconds) do
        expect(api_import_csv(wallet, name)).to be_successful
      end
    end

    snapshots = Wallet.order(name: :asc, id: :asc).map { |w| generate_wallet_snapshot(w) }

    # postgres on mac doesnt sort in same way as on linux/herku so we have to fall back to sorting normally
    first_imports = CsvImport.order(file_file_name: :asc).sort_by(&:file_file_name)
    wallet_snapshot = snapshots.count == 1 ? snapshots[0] : { wallets: snapshots }
    wallet_snapshot[:csv_imports] = first_imports.map { |imp| imp.results.merge(file_name: imp.file_file_name).except('errors', 'skipped') }
    expect(wallet_snapshot).to match_snapshot('csv_imports/' + id)

    # ensure it doesnt reimport duplicates
    file_names.map.with_index do |name, idx|
      Timecop.travel(Time.now + 1.minute + idx.seconds) do
        expect { api_import_csv(wallet, name) }.not_to change { Entry.count }
      end
    end

    second_csv_imports = CsvImport.where.not(id: first_imports.map(&:id))
    expect(second_csv_imports.sum(&:success_count)).to eq 0
    expect(second_csv_imports.sum(&:skipped_count) + second_csv_imports.sum(&:duplicate_count)).to eq(first_imports.sum(&:success_count) + first_imports.sum(&:skipped_count) + first_imports.sum(&:duplicate_count))
    expect(second_csv_imports.sum(&:error_count)).to eq first_imports.sum(&:error_count)
  end
end

def api_fetch_csv_status
  json = JSON.parse(response.body)
  get(
    "/api/csv_imports/#{json['id']}",
    headers: {
      'X-Auth-Token': current_user.api_token
    }
  )
  JSON.parse response.body
end

def api_import_csv(wallet, csv, options = {})
  mime_type = options.delete(:mime) || "text/csv"
  post(
    '/api/csv_imports',
    params: {
      csv_import: {
                    wallet_id: wallet.id,
                    file: fixture_file_upload('files/' + csv, mime_type)
                  }.merge(options)
    },
    headers: {
      'X-Auth-Token': current_user.api_token
    }
  )
  response
end
