source 'http://rubygems.org'

case version = ENV['MONGOID_VERSION'] || '3.1'
when /3/
  gem 'mongoid', '~> 3.1'
else
  gem 'mongoid', version
end

gemspec

group :test do
  gem 'rspec'
end

group :development do
  gem 'rake'
  gem 'rubocop', '0.34.1'
end
