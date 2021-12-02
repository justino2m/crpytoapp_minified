require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CryptoApp
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.load_defaults 5.2
    config.active_record.sqlite3.represent_boolean_as_integer = true
    config.eager_load_paths += Dir[Rails.root.join("app", "models", "{*/}")]
    config.eager_load_paths += Dir[Rails.root.join("app", "importers", "{*/}")]

    config.active_job.queue_adapter = :sidekiq

    config.generators.assets = false
    config.generators.helper = false
  end
end

if Rails.env.test? && defined? RSpec
  # this has to go in here
  RSpec.configure do |config|
    config.swagger_dry_run = false
  end
end
