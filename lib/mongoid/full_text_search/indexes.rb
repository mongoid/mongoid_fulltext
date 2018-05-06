module Mongoid
  module FullTextSearch
    module Indexes
      extend ActiveSupport::Concern

      module ClassMethods
        def create_fulltext_indexes
          return unless mongoid_fulltext_config
          mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
            ::I18n.available_locales.each do |locale|
              fulltext_search_ensure_indexes(localized_index_name(index_name, locale), fulltext_config)
            end
          end
        end

        def localized_index_name(index_name, locale)
          return index_name unless fields.values.any?(&:localized?)
          return index_name unless ::I18n.available_locales.count > 1
          "#{index_name}_#{locale}"
        end

        def fulltext_search_ensure_indexes(index_name, config)
          db = collection.database
          coll = db[index_name]

          # The order of filters matters when the same index is used from two or more collections.
          filter_indexes = (config[:filters] || []).map do |key, _value|
            ["filter_values.#{key}", 1]
          end.sort_by { |filter_index| filter_index[0] }

          index_definition = [['ngram', 1], ['score', -1]].concat(filter_indexes)

          # Since the definition of the index could have changed, we'll clean up by
          # removing any indexes that aren't on the exact.
          correct_keys = index_definition.map { |field_def| field_def[0] }
          all_filter_keys = filter_indexes.map { |field_def| field_def[0] }
          coll.indexes.each do |idef|
            keys = idef['key'].keys
            next unless keys.member?('ngram')
            all_filter_keys |= keys.find_all { |key| key.starts_with?('filter_values.') }
            next unless keys & correct_keys != correct_keys
            Mongoid.logger.info "Dropping #{idef['name']} [#{keys & correct_keys} <=> #{correct_keys}]" if Mongoid.logger
            if Mongoid::Compatibility::Version.mongoid5_or_newer?
              coll.indexes.drop_one(idef['key'])
            else
              coll.indexes.drop(idef['key'])
            end
          end

          if all_filter_keys.length > filter_indexes.length
            filter_indexes = all_filter_keys.map { |key| [key, 1] }.sort_by { |filter_index| filter_index[0] }
            index_definition = [['ngram', 1], ['score', -1]].concat(filter_indexes)
          end

          Mongoid.logger.info "Ensuring fts_index on #{coll.name}: #{index_definition}" if Mongoid.logger
          if Mongoid::Compatibility::Version.mongoid5_or_newer?
            coll.indexes.create_one(Hash[index_definition], name: 'fts_index')
          else
            coll.indexes.create(Hash[index_definition], name: 'fts_index')
          end

          Mongoid.logger.info "Ensuring document_id index on #{coll.name}" if Mongoid.logger
          if Mongoid::Compatibility::Version.mongoid5_or_newer?
            coll.indexes.create_one('document_id' => 1) # to make removes fast
          else
            coll.indexes.create('document_id' => 1) # to make removes fast
          end
        end
      end
    end
  end
end
