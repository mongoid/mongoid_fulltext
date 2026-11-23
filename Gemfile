source 'https://rubygems.org'

version = ENV['MONGOID_VERSION'] || '9'
gem 'bigdecimal' if RUBY_VERSION >= '3.4'
gem 'logger' if RUBY_VERSION >= '2.5'
gem 'mongoid', version =~ /\A\d+\z/ ? "~> #{version}.0" : version

gemspec

group :test do
  if RUBY_VERSION >= '2.7'
    gem 'database_cleaner-mongoid', '~> 2.0'
  else
    gem 'database_cleaner', '~> 1.8'
  end
  gem 'rspec'
  gem 'simplecov', RUBY_VERSION < '2.5' ? '~> 0.16.0' : '~> 0.22', require: false if ENV['COVERAGE'] == 'true'
end

group :development do
  gem 'rake'
  if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3')
    gem 'commonmarker', '~> 2.10', require: false
    gem 'rubocop', '~> 1.92'
    gem 'rubocop-md', '~> 3.0', require: false
    gem 'rubocop-prose', '~> 0.2', require: false
    gem 'rubocop-rake', '~> 0.7', require: false
    gem 'rubocop-spellcheck', '~> 0.2', require: false
    gem 'rubocop-yaml', '~> 0.1.0', require: false
    gem 'ruby-gem-release', '0.9.0', require: false
  end
end
