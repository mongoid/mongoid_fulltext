require 'mongoid/full_text_search/config'
require 'mongoid/full_text_search/indexes'
require 'mongoid/full_text_search/mappings'
require 'mongoid/full_text_search/ngrams'
require 'mongoid/full_text_search/searchable'

module Mongoid
  module FullTextSearch
    extend ActiveSupport::Concern

    include Config
    include Indexes
    include Mappings
    include Ngrams
    include Searchable
  end
end
