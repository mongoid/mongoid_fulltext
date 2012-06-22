require 'rubygems'
require 'bundler/setup'
require 'rspec'

require 'mongoid'

ENV['MONGOID_ENV'] = 'test'

Mongoid.load!("#{File.dirname(__FILE__)}/config/mongoid.yml")
Mongoid.logger = nil

require File.expand_path("../../lib/mongoid_fulltext", __FILE__)
Dir["#{File.dirname(__FILE__)}/models/**/*.rb"].each { |f| require f }

Rspec.configure do |c|
  c.before(:each) do
    Mongoid.session(:default).drop
  end
  c.after(:all) do 
    Mongoid.session(:default).drop
  end
end

