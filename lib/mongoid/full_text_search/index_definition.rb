module Mongoid
  module FullTextSearch
    # Plans search keys and obsolete indexes while retaining shared-model filters.
    class IndexDefinition
      attr_reader :keys, :obsolete_indexes

      def initialize(filters, localized, existing_indexes)
        filter_keys = (filters || {}).map { |key, _value| "filter_values.#{key}" }.sort
        @keys = build_keys(filter_keys, localized)
        correct_keys = @keys.map(&:first)
        all_filter_keys = filter_keys.dup
        @obsolete_indexes = existing_indexes.find_all do |index|
          keys = index['key'].keys
          next false unless keys.member?('ngram')

          all_filter_keys |= keys.find_all { |key| key.start_with?('filter_values.') }
          keys & correct_keys != correct_keys
        end
        @keys = build_keys(all_filter_keys.sort, localized) if all_filter_keys.length > filter_keys.length
      end

      private

      def build_keys(filter_keys, localized)
        keys = [['ngram', 1], ['score', -1]].concat(filter_keys.map { |key| [key, 1] })
        keys.unshift(['locale', 1]) if localized
        keys
      end
    end
  end
end
