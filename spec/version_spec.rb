require 'spec_helper'

describe Mongoid::FullTextSearch do
  it 'defines a semantic version' do
    expect(Mongoid::FullTextSearch::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end
end
