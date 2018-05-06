require 'mongoid/full_text_search/config'
require 'mongoid/full_text_search/indexes'
require 'mongoid/full_text_search/mappings'
require 'mongoid/full_text_search/ngrams'
require 'mongoid/full_text_search/searchable'

module Mongoid
  module FullTextSearch
    class UnknownFilterQueryOperator < StandardError; end
    class UnspecifiedIndexError < StandardError; end

    CREATE_INDEX_METHOD_NAME = Mongoid::Compatibility::Version.mongoid5_or_newer? ? :create_one : :create
    DELETE_FROM_INDEX_METHOD_NAME = Mongoid::Compatibility::Version.mongoid5_or_newer? ? :delete_many : :remove_all
    DROP_INDEX_METHOD_NAME = Mongoid::Compatibility::Version.mongoid5_or_newer? ? :drop_one : :drop
    INSERT_METHOD_NAME = Mongoid::Compatibility::Version.mongoid5_or_newer? ? :insert_one : :insert

    extend ActiveSupport::Concern

    include Config
    include Indexes
    include Mappings
    include Ngrams
    include Searchable
  end
end
