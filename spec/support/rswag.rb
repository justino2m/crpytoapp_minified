RSpec.configure do |config|
  config.after do |example|
    if example.metadata[:rerun_file_path]&.include?('/spec/integration/api') && response && example.metadata[:response]
      example.metadata[:response][:examples] = {
        'application/json' => JSON.parse(response.body, symbolize_names: true)
      }
    end
  end
end
