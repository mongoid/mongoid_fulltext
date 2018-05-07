require 'mongoid/full_text_search/config'
require 'mongoid/full_text_search/indexes'
require 'mongoid/full_text_search/mappings'
require 'mongoid/full_text_search/searchable'

module Mongoid
  module FullTextSearch
    class UnknownFilterQueryOperator < StandardError; end
    class UnspecifiedIndexError < StandardError; end

    CREATE_INDEX_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :create_one : :create
    DELETE_FROM_INDEX_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :delete_many : :remove_all
    DROP_INDEX_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :drop_one : :drop
    INSERT_METHOD_NAME = Compatibility::Version.mongoid5_or_newer? ? :insert_one : :insert

    DEFAULT_CONFIG = {
      alphabet: 'abcdefghijklmnopqrstuvwxyz0123456789 ',
      apply_prefix_scoring_to_all_words: true,
      index_full_words: true,
      index_short_prefixes: false,
      max_candidate_set_size: 1000,
      max_ngrams_to_search: 6,
      ngram_width: 3,
      reindex_immediately: true,
      remove_accents: true,
      word_separators: "-_ \n\t",
      stop_words: Hash[
        %w[i a s t me my we he it am is be do an if
           or as of at by to up in on no so our you him
           his she her its who are was has had did the and
           but for out off why how all any few nor not own
           too can don now ours your hers they them what whom
           this that were been have does with into from down over
           then once here when both each more most some such only
           same than very will just yours their which these those
           being doing until while about after above below under
           again there where other myself itself theirs having during
           before should himself herself because against between through
           further yourself ourselves yourselves themselves].map { |x| [x, true] }]
    }

    extend ActiveSupport::Concern

    include Config
    include Indexes
    include Mappings
    include Searchable
  end
end
