module Mongoid
  module FullTextSearch
    class IndexDefinition < Struct.new(:coll, :filters)
      def self.call(*args)
        new(*args).call
      end

      def call
        res = index_definition
        all_filter_keys = filter_indexes.map(&:first)

        # Since the definition of the index could have changed, we'll clean up by
        # removing any indexes that aren't on the exact.
        coll.indexes.each do |idef|
          keys = idef['key'].keys
          next unless keys.member?('ngram')
          all_filter_keys |= keys.find_all { |key| key.starts_with?('filter_values.') }
          next unless keys & correct_keys != correct_keys
          Mongoid.logger.info "Dropping #{idef['name']} [#{keys & correct_keys} <=> #{correct_keys}]" if Mongoid.logger
          coll.indexes.send DROP_INDEX_METHOD_NAME, idef['key']
        end

        if all_filter_keys.length > filter_indexes.length
          updated_filter_indexes = all_filter_keys.map { |key| [key, 1] }.sort_by(&:first)
          res = [['ngram', 1], ['score', -1]].concat(updated_filter_indexes)
        end

        res
      end

      # The order of filters matters when the same index is used from two or more collections.
      def filter_indexes
        filters.map { |key, _| ["filter_values.#{key}", 1] }.sort_by(&:first)
      end

      def index_definition
        [['ngram', 1], ['score', -1]].concat(filter_indexes)
      end

      def correct_keys
        index_definition.map { |field_def| field_def[0] }
      end
    end
  end
end
