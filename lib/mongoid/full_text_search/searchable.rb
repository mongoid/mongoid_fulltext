module Mongoid
  module FullTextSearch
    class UnspecifiedIndexError < StandardError; end
    class UnknownFilterQueryOperator < StandardError; end

    module Searchable
      extend ActiveSupport::Concern

      module ClassMethods
        def fulltext_search(query_string, options = {})
          max_results = options.key?(:max_results) ? options.delete(:max_results) : 10
          return_scores = options.key?(:return_scores) ? options.delete(:return_scores) : false
          if mongoid_fulltext_config.count > 1 && !options.key?(:index)
            error_message = '%s is indexed by multiple full-text indexes. You must specify one by passing an :index_name parameter'
            raise UnspecifiedIndexError, error_message % name, caller
          end
          index_name = options.key?(:index) ? options.delete(:index) : mongoid_fulltext_config.keys.first

          loc_index_name = localized_index_name(index_name, ::I18n.locale)
          # Options hash should only contain filters after this point

          ngrams = all_ngrams(query_string, mongoid_fulltext_config[index_name])
          return [] if ngrams.empty?

          # For each ngram, construct the query we'll use to pull index documents and
          # get a count of the number of index documents containing that n-gram
          ordering = { 'score' => -1 }
          limit = mongoid_fulltext_config[index_name][:max_candidate_set_size]
          coll = collection.database[loc_index_name]
          cursors = ngrams.map do |ngram|
            query = { 'ngram' => ngram[0] }
            query.update(document_type_filters)
            query.update(map_query_filters(options))
            count = coll.find(query).count
            { ngram: ngram, count: count, query: query }
          end.sort! { |record1, record2| record1[:count] <=> record2[:count] }

          # Using the queries we just constructed and the n-gram frequency counts we
          # just computed, pull in about *:max_candidate_set_size* candidates by
          # considering the n-grams in order of increasing frequency. When we've
          # spent all *:max_candidate_set_size* candidates, pull the top-scoring
          # *max_results* candidates for each remaining n-gram.
          results_so_far = 0
          candidates_list = cursors.map do |doc|
            next if doc[:count] == 0
            query_result = coll.find(doc[:query])
            if results_so_far >= limit
              query_result = query_result.sort(ordering).limit(max_results)
            elsif doc[:count] > limit - results_so_far
              query_result = query_result.sort(ordering).limit(limit - results_so_far)
            end
            results_so_far += doc[:count]
            ngram_score = ngrams[doc[:ngram][0]]
            Hash[query_result.map do |candidate|
              [candidate['document_id'],
               { clazz: candidate['class'], score: candidate['score'] * ngram_score }]
            end]
          end.compact

          # Finally, score all candidates by matching them up with other candidates that are
          # associated with the same document. This is similar to how you might process a
          # boolean AND query, except that with an AND query, you'd stop after considering
          # the first candidate list and matching its candidates up with candidates from other
          # lists, whereas here we want the search to be a little fuzzier so we'll run through
          # all candidate lists, removing candidates as we match them up.
          all_scores = []
          until candidates_list.empty?
            candidates = candidates_list.pop
            scores = candidates.map do |candidate_id, data|
              { id: candidate_id,
                clazz: data[:clazz],
                score: data[:score] + candidates_list.map { |others| (others.delete(candidate_id) || { score: 0 })[:score] }.sum }
            end
            all_scores.concat(scores)
          end
          all_scores.sort! { |document1, document2| -document1[:score] <=> -document2[:score] }
          instantiate_mapreduce_results(all_scores[0..max_results - 1], return_scores: return_scores)
        end

        def instantiate_mapreduce_result(result)
          if criteria.selector.empty?
            result[:clazz].constantize.find(result[:id])
          else
            criteria.where(_id: result[:id]).first
          end
        end

        def instantiate_mapreduce_results(results, options)
          if options[:return_scores]
            results.map { |result| [instantiate_mapreduce_result(result), result[:score]] }.find_all { |result| !result[0].nil? }
          else
            results.map { |result| instantiate_mapreduce_result(result) }.compact
          end
        end

        private

        # add filter by type according to SCI classes
        def document_type_filters
          return {} unless fields['_type'].present?
          kls = ([self] + descendants).map(&:to_s)
          { 'document_type' => { '$in' => kls } }
        end

        # Take a list of filters to be mapped so they can update the query
        # used upon the fulltext search of the ngrams
        def map_query_filters(filters)
          Hash[filters.map do |key, value|
            case value
            when Hash then
              if value.key? :any then format_query_filter('$in', key, value[:any])
              elsif value.key? :all then format_query_filter('$all', key, value[:all])
              else raise UnknownFilterQueryOperator, value.keys.join(','), caller end
            else format_query_filter('$all', key, value)
            end
          end]
        end

        def format_query_filter(operator, key, value)
          [format('filter_values.%s', key), { operator => [value].flatten }]
        end
      end
    end
  end
end
