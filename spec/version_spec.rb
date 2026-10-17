require 'spec_helper'

describe Mongoid::FullTextSearch do
  it 'loads a standalone semantic version' do
    stub_const('Mongoid::FullTextSearch', Module.new)
    load File.expand_path('../lib/mongoid/full_text_search/version.rb', __dir__)
    expect(Mongoid::FullTextSearch::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
