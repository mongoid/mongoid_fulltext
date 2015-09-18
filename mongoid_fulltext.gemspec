$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'mongoid/full_text_search/version'

Gem::Specification.new do |s|
  s.name = 'mongoid_fulltext'
  s.version = Mongoid::FullTextSearch::VERSION
  s.authors = ['Aaron Windsor']
  s.email = 'aaron.windsor@gmail.com'
  s.platform = Gem::Platform::RUBY
  s.required_rubygems_version = '>= 1.3.6'
  s.files = `git ls-files`.split("\n")
  s.require_paths = ['lib']
  s.homepage = 'https://github.com/artsy/mongoid_fulltext'
  s.licenses = ['MIT']
  s.summary = 'Full-text search for the Mongoid ORM, using n-grams extracted from text.'
  s.add_dependency 'mongoid', '>= 3.0'
  s.add_dependency 'mongoid-compatibility'
  s.add_dependency 'unicode_utils'
end
