require "rails_helper"

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you"re using the rswag-api to serve API descriptions, you"ll need
  # to ensure that it"s confiugred to server Swagger from the same folder
  config.swagger_root = Rails.root.to_s + "/public/api-docs"

  config.swagger_docs = {
    'v1/swagger.json' => {
      swagger: '2.0',
      info: {
        title: 'Crypto API',
        version: 'v1'
      },
      paths: {},
      securityDefinitions: {
        apiToken: {
          type: :apiKey,
          name: 'X-Auth-Token',
          in: :header
        }
      },
      security: [
        { apiToken: [] }
      ]
    }
  }
end
