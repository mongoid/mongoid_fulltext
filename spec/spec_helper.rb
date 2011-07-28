require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'

Mongoid.configure do |config|
  name = "mongoid_fulltext_test"
  config.master = Mongo::Connection.new.db(name)
  config.logger = Logger.new('/dev/null')
end

require File.expand_path("../../lib/mongoid_fulltext", __FILE__)
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

Rspec.configure do |c|
  c.before(:each) do
    Mongoid.master.collections.select {|c| c.name !~ /system/ }.each(&:drop)
  end
  c.after(:all) do 
    Mongoid.master.command({'dropDatabase' => 1})
  end
end

