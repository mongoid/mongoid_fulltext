require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'

ENV['MONGOID_ENV'] = 'test'

require File.expand_path('../../lib/mongoid_fulltext', __FILE__)

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

Mongoid.configure do |config|
  config.connect_to('mongoid_fulltext_test')
end

RSpec.configure do |c|
  c.before :each do
    Mongoid.purge!
  end
  c.after :all do
    Mongoid.purge!
  end
  c.before :all do
    Mongoid.logger.level = Logger::INFO
    Mongo::Logger.logger.level = Logger::INFO if Mongoid::Compatibility::Version.mongoid5? || Mongoid::Compatibility::Version.mongoid6?
  end
end
