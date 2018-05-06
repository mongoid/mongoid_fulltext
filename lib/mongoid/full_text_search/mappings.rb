module Mongoid
  module FullTextSearch
    module Mappings
      extend ActiveSupport::Concern

      module ClassMethods
        def fulltext_search_in(*args)
          options = args.last.is_a?(Hash) ? args.pop : {}

          index_name = options.fetch(:index_name) do
            "mongoid_fulltext.index_#{name.downcase}_#{mongoid_fulltext_config.count}"
          end

          config = default_config.update(options)

          args = [:to_s] if args.empty?
          config[:ngram_fields] = args
          config[:alphabet] = Hash[config[:alphabet].split('').map { |ch| [ch, ch] }]
          config[:word_separators] = Hash[config[:word_separators].split('').map { |ch| [ch, ch] }]

          mongoid_fulltext_config[index_name] = config

          before_save(:update_ngram_index) if config[:reindex_immediately]
          before_destroy(:remove_from_ngram_index)
        end

        def update_ngram_index
          all.each(&:update_ngram_index)
        end

        private

        def default_config
          {
            alphabet: 'abcdefghijklmnopqrstuvwxyz0123456789 ',
            word_separators: "-_ \n\t",
            ngram_width: 3,
            max_ngrams_to_search: 6,
            apply_prefix_scoring_to_all_words: true,
            index_full_words: true,
            index_short_prefixes: false,
            max_candidate_set_size: 1000,
            remove_accents: true,
            reindex_immediately: true,
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
        end
      end

      def update_ngram_index
        mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
          ::I18n.available_locales.each do |locale|
            loc_index_name = self.class.localized_index_name(index_name, locale)

            if condition = fulltext_config[:update_if]
              case condition
              when Symbol then  next unless send condition
              when String then  next unless instance_eval condition
              when Proc then    next unless condition.call self
              else; next
              end
            end

            # remove existing ngrams from external index
            coll = collection.database[loc_index_name.to_sym]
            coll.find(document_id: _id).send(DELETE_FROM_INDEX_METHOD_NAME)

            # extract ngrams from fields
            field_values = fulltext_config[:ngram_fields].map do |field_name|
              next send(field_name) if field_name == :to_s
              next unless field = self.class.fields[field_name.to_s]
              field.localized? ? send("#{field_name}_translations")[locale] : send(field_name)
            end

            ngrams = field_values.inject({}) do |accum, item|
              accum.update(self.class.all_ngrams(item, fulltext_config, false))
            end

            return if ngrams.empty?

            # apply filters, if necessary
            filter_values = nil
            if fulltext_config.key?(:filters)
              filter_values = Hash[
                fulltext_config[:filters].map do |key, value|
                  begin
                    [key, value.call(self)]
                  rescue StandardError # Suppress any exceptions caused by filters
                  end
                end.compact
              ]
            end

            # insert new ngrams in external index
            ngrams.each_pair do |ngram, score|
              index_document = {
                class: self.class.name,
                document_id: _id,
                ngram: ngram,
                score: score
              }

              index_document[:filter_values] = filter_values if fulltext_config.key?(:filters)

              coll.send INSERT_METHOD_NAME, index_document
            end
          end
        end
      end

      def remove_from_ngram_index
        mongoid_fulltext_config.each_pair do |index_name, _|
          ::I18n.available_locales.each do |locale|
            coll = collection.database[self.class.localized_index_name(index_name, locale)]
            coll.find(document_id: _id).send(DELETE_FROM_INDEX_METHOD_NAME)
          end
        end
      end
    end
  end
end
