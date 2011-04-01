require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'
require 'database_cleaner'

Mongoid.configure do |config|
  name = "mongoid_fulltext_test"
  config.master = Mongo::Connection.new.db(name)
end

require File.expand_path("../../lib/mongoid_fulltext", __FILE__)
Dir["#{File.dirname(__FILE__)}/models/*.rb"].each { |f| require f }

Rspec.configure do |c|
  c.before(:all)  { DatabaseCleaner.strategy = :truncation }
  c.before(:each) { DatabaseCleaner.clean }
end

