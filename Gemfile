source 'https://rubygems.org'
ruby '2.5.1'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

gem 'rails', '~> 5.2.0'
gem 'countries'
gem 'active_model_serializers'
gem 'kaminari'
gem 'ransack', '~> 1.8.2'
gem 'rack-cors', require: 'rack/cors'
gem 'bcrypt'
gem 'paperclip', '~> 5.0.0'
gem 'cancancan'
gem 'state_machines-activerecord'
gem 'dotenv-rails'
gem 'aws-sdk', '< 3.0'
gem 'pg'
gem 'mini_magick', '~> 4.8'
gem 'bootsnap', '>= 1.1.0', require: false
gem 'money'
gem 'redis', '~> 4.0'
gem 'sidekiq'
gem 'sidekiq-unique-jobs', "~> 6.0.16"
gem 'oauth2'
gem 'http'
gem 'nokogiri'
gem 'roo'
gem 'axlsx', git: 'https://github.com/randym/axlsx.git', ref: 'c8ac844'
gem 'axlsx_rails'
gem 'rollbar'
gem 'activerecord-import'
gem 'geocoder'
gem 'iso_country_codes'
gem 'stripe'
gem 'rest-client'
gem 'google-id-token'
gem 'money-tree', git: 'https://github.com/NicosKaralis/money-tree.git', ref: '2af4698'
gem 'awesome_print'
gem 'jsonb_accessor'

gem 'faker' # used in seeds
gem 'rswag'
gem 'rspec-rails'
gem 'bitcoin'

# create tax reports
gem 'prawn'
# used to position items on tax reports pages
gem 'prawn-table'
# used to overlay prawn reports with tax forms and combine pages together
gem 'combine_pdf'

# gem 'api_ruby_base', git: 'https://bitbucket.org/robinsingh/api_ruby_base.git'
# gem 'api_ruby_base', path: '../api_ruby_base'

group :development, :test do
  gem 'vcr'
  gem 'webmock'
  gem 'listen'
  gem 'byebug', platform: :mri
  gem 'factory_bot_rails'
end

group :test do
  gem 'shoulda-matchers'
  gem 'database_cleaner'
  gem 'json-schema'
  gem 'json-schema-generator'
  gem 'capybara', '>= 2.15', '< 4.0'
  gem 'selenium-webdriver'
  gem 'chromedriver-helper'
  gem 'pdf-inspector', require: "pdf/inspector"
  gem 'timecop'
end

group :development do
  gem 'mailcatcher'
end

group :production do
  gem 'puma'
  gem 'rails_12factor'
end
