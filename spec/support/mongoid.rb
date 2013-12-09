# encoding: UTF-8

RSpec.configure do |config|
  config.include Mongoid::Matchers, type: :model
end
