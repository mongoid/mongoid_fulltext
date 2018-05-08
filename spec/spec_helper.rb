require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'
require 'database_cleaner'

ENV['MONGOID_ENV'] = 'test'

require File.expand_path('../lib/mongoid_fulltext', __dir__)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

DatabaseCleaner.orm = :mongoid
DatabaseCleaner.strategy = :truncation

Mongoid.logger.level = Logger::INFO
Mongo::Logger.logger.level = Logger::INFO if Mongoid::Compatibility::Version.mongoid5_or_newer?

Mongoid.configure do |config|
  config.connect_to('mongoid_fulltext_test')
end

::I18n.available_locales = %i[en cs]

RSpec.configure do |c|
  c.before :each do
    DatabaseCleaner.clean
  end
  c.after :all do
    DatabaseCleaner.clean
  end
end
