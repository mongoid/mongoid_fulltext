require 'mongoid/full_text_search/index_definition'

module Mongoid
  module FullTextSearch
    module Indexes
      extend ActiveSupport::Concern

      module ClassMethods
        def create_fulltext_indexes
          return unless mongoid_fulltext_config

          mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
            ::I18n.available_locales.each do |locale|
              fulltext_search_ensure_indexes(
                localized_index_name(index_name, locale), fulltext_config
              )
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
          filters = config.fetch(:filters, [])
          index_definition = IndexDefinition.call(coll, filters)

          Mongoid.logger.info("Ensuring fts_index on #{coll.name}: #{index_definition}") if Mongoid.logger
          coll.indexes.send create_index_method_name, Hash[index_definition], name: 'fts_index'

          Mongoid.logger.info("Ensuring document_id index on #{coll.name}") if Mongoid.logger
          coll.indexes.send create_index_method_name, { document_id: 1 }
        end

        private

        def create_index_method_name
          return :create unless Mongoid::Compatibility::Version.mongoid5_or_newer?
          :create_one
        end
      end
    end
  end
end
