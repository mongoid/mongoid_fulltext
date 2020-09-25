source 'http://rubygems.org'

case version = ENV['MONGOID_VERSION'] || '7'
when /7/
  gem 'mongoid', '~> 7.0'
when /6/
  gem 'mongoid', '~> 6.0'
when /5/
  gem 'mongoid', '~> 5.0'
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
  gem 'mongoid-danger', '~> 0.1.1'
  gem 'rake', '< 11'
  gem 'rubocop', '0.55'
end
