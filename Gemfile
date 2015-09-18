source 'http://rubygems.org'

case version = ENV['MONGOID_VERSION'] || '4'
when /4/
  gem 'mongoid', '~> 4.0'
when /3.1.0/
  gem 'mongoid', '~> 3.1.0'
when /3.0.0/
  gem 'mongoid', '~> 3.0.0'
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
