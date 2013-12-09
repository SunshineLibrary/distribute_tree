# encoding: UTF-8

$LOAD_PATH.unshift(File.dirname(__FILE__))
ENV['RAILS_ENV'] ||= 'test'

require_relative 'dummy/config/environment'
require 'rspec/rails'
require 'rspec/autorun'
require 'mongoid-rspec'
require 'factory_girl_rails'
require 'rails/mongoid'

require 'capybara/rails'
require 'capybara/rspec'

require 'database_cleaner'

config.before :each do
  Mongoid.purge!
end

config.before(:suite) do
  DatabaseCleaner.strategy = :truncation
  DatabaseCleaner.orm = "mongoid"
end

Rails.backtrace_cleaner.remove_silencers!

RSpec.configure do |config|
  config.mock_with :rspec
  config.use_transactional_fixtures = true
  config.infer_base_class_for_anonymous_controllers = false

  config.after(:each, :type => :request) do
    DatabaseCleaner.clean       # Truncate the database
    Capybara.reset_sessions!    # Forget the (simulated) browser state
    Capybara.use_default_driver # Revert Capybara.current_driver to Capybara.default_driver
  end
end
