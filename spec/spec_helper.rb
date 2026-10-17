require 'rubygems'
require 'bundler/setup'
if ENV['COVERAGE'] == 'true'
  require 'simplecov'
  SimpleCov.start do
    track_files 'lib/**/*.rb'
    add_filter '/spec/'
  end
end
require 'rspec'

require 'logger'
require 'mongoid'
require RUBY_VERSION >= '2.7' ? 'database_cleaner/mongoid' : 'database_cleaner'

ENV['MONGOID_ENV'] = 'test'

require File.expand_path('../lib/mongoid_fulltext', __dir__)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

DatabaseCleaner[:mongoid].strategy = RUBY_VERSION >= '2.7' ? :deletion : :truncation

Mongoid.logger.level = Logger::INFO
Mongo::Logger.logger.level = Logger::INFO if Mongoid::Compatibility::Version.mongoid5_or_newer?

Mongoid.configure do |config|
  config.connect_to('mongoid_fulltext_test')
  if Mongoid::Compatibility::Version.mongoid5_or_newer?
    config.clients['default']['hosts'] = [ENV.fetch('MONGODB_HOST', 'localhost:27017')]
  else
    config.sessions['default']['hosts'] = [ENV.fetch('MONGODB_HOST', 'localhost:27017')]
  end
end

RSpec.configure do |c|
  c.before :each do
    DatabaseCleaner.clean
  end
  c.after :all do
    DatabaseCleaner.clean
  end
end
