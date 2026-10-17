require 'mongoid'
require 'mongoid/compatibility'

if Mongoid::Compatibility::Version.mongoid3?
  require 'mongoid/full_text_search/indexes'
else
  require 'mongoid/full_text_search/indexable'
end

require 'cgi'
require 'mongoid/full_text_search/ngrams'
require 'mongoid/full_text_search/index_definition'
require 'mongoid/full_text_search/field_scores'

module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :mongoid_fulltext_config
  end

  class UnspecifiedIndexError < StandardError; end
  class UnknownFilterQueryOperator < StandardError; end

  module ClassMethods
    def fulltext_search_in(*args)
      self.mongoid_fulltext_config = {} if mongoid_fulltext_config.nil?
      options = args.last.is_a?(Hash) ? args.pop : {}
      index_name = if options.key?(:index_name)
                     options[:index_name]
                   else
                     'mongoid_fulltext.index_%s_%s' % [name.downcase, mongoid_fulltext_config.count]
                   end

      config = {
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
        stop_words: Hash[%w[i a s t me my we he it am is be do an if
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

      config.update(options)

      raise ArgumentError, ':alphabet must be a String or Regexp' unless config[:alphabet].is_a?(String) || config[:alphabet].is_a?(Regexp)
      raise ArgumentError, ':max_ngrams_to_search must be a positive integer' unless config[:max_ngrams_to_search].is_a?(Integer) && config[:max_ngrams_to_search] > 0

      args = [:to_s] if args.empty?
      FieldScores.configure(config, args)
      config[:ngram_fields] = args
      config[:alphabet] = Hash[config[:alphabet].split('').map { |ch| [ch, ch] }] if config[:alphabet].is_a?(String)
      config[:word_separators] = Hash[config[:word_separators].split('').map { |ch| [ch, ch] }]
      mongoid_fulltext_config[index_name] = config

      before_save(:update_ngram_index) if config[:reindex_immediately]
      before_destroy :remove_from_ngram_index
    end

    def create_fulltext_indexes
      return unless mongoid_fulltext_config

      mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
        fulltext_search_ensure_indexes(index_name, fulltext_config)
      end
    end

    def localized_fulltext_index?(config)
      config[:ngram_fields].any? do |field_name|
        field = fields[field_name.to_s]
        field && field.localized?
      end
    end

    def each_fulltext_index
      mongoid_fulltext_config.each_pair do |index_name, config|
        if localized_fulltext_index?(config)
          I18n.available_locales.each do |locale|
            I18n.with_locale(locale) { yield index_name, config, locale.to_s }
          end
        else
          yield index_name, config, nil
        end
      end
    end

    def fulltext_search_ensure_indexes(index_name, config)
      db = collection.database
      coll = db[index_name]

      # Creating an index also creates the collection before older drivers list its indexes.
      Mongoid.logger.info "Ensuring document_id index on #{coll.name}" if Mongoid.logger
      if Mongoid::Compatibility::Version.mongoid5_or_newer?
        coll.indexes.create_one('document_id' => 1)
      else
        coll.indexes.create('document_id' => 1)
      end

      existing_indexes = []
      coll.indexes.each { |index| existing_indexes << index }
      definition = IndexDefinition.new(config[:filters], localized_fulltext_index?(config), existing_indexes)
      definition.obsolete_indexes.each do |idef|
        Mongoid.logger.info "Dropping #{idef['name']} [#{idef['key'].keys} <=> #{definition.keys.map(&:first)}]" if Mongoid.logger
        if Mongoid::Compatibility::Version.mongoid5_or_newer?
          coll.indexes.drop_one(idef['key'])
        else
          coll.indexes.drop(idef['key'])
        end
      end

      index_definition = definition.keys
      Mongoid.logger.info "Ensuring fts_index on #{coll.name}: #{index_definition}" if Mongoid.logger
      if Mongoid::Compatibility::Version.mongoid5_or_newer?
        coll.indexes.create_one(Hash[index_definition], name: 'fts_index')
      else
        coll.indexes.create(Hash[index_definition], name: 'fts_index')
      end
    end

    def fulltext_search(query_string, options = {})
      max_results = options.key?(:max_results) ? options.delete(:max_results) : 10
      return_scores = options.key?(:return_scores) ? options.delete(:return_scores) : false
      if mongoid_fulltext_config.count > 1 && !options.key?(:index)
        error_message = '%s is indexed by multiple full-text indexes. You must specify one by passing an :index_name parameter'
        raise UnspecifiedIndexError, error_message % name, caller
      end
      index_name = options.key?(:index) ? options.delete(:index) : mongoid_fulltext_config.keys.first

      # Options hash should only contain filters after this point

      ngrams = all_ngrams(query_string, mongoid_fulltext_config[index_name])
      return [] if ngrams.empty?

      # For each ngram, construct the query we'll use to pull index documents and
      # get a count of the number of index documents containing that n-gram
      ordering = { 'score' => -1 }
      limit = mongoid_fulltext_config[index_name][:max_candidate_set_size]
      config = mongoid_fulltext_config[index_name]
      coll = collection.database[index_name]
      cursors = ngrams.map do |ngram|
        query = { 'ngram' => ngram[0] }
        query['locale'] = I18n.locale.to_s if localized_fulltext_index?(config)
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
      if max_results > 0
        instantiate_mapreduce_results(all_scores, return_scores: return_scores, max_results: max_results)
      else
        instantiate_mapreduce_results(all_scores[0..max_results - 1], return_scores: return_scores)
      end
    end

    def instantiate_mapreduce_result(result)
      scope = criteria
      scope = result[:clazz].constantize.criteria if scope.selector.empty?
      scope.where(_id: result[:id]).first
    end

    def instantiate_mapreduce_results(results, options)
      results.each_with_object([]) do |result, documents|
        document = instantiate_mapreduce_result(result)
        next unless document

        documents << (options[:return_scores] ? [document, result[:score]] : document)
        break documents if options[:max_results] && documents.length >= options[:max_results]
      end
    end

    def all_ngrams(str, config, bound_number_returned = true)
      Ngrams.calculate(str, config, bound_number_returned)
    end

    def remove_from_ngram_index
      mongoid_fulltext_config.each_pair do |index_name, _fulltext_config|
        coll = collection.database[index_name]
        if Mongoid::Compatibility::Version.mongoid5_or_newer?
          coll.find('class' => name).delete_many
        else
          coll.find('class' => name).remove_all
        end
      end
    end

    def update_ngram_index(options = { timeout: true })
      items = all
      items = items.no_timeout if options.key?(:timeout) && !options[:timeout]
      items.each(&:update_ngram_index)
    end

    private

    def document_type_filters
      return {} if criteria.selector.empty? && descendants.empty? && !superclass.respond_to?(:mongoid_fulltext_config)

      { 'class' => { '$in' => ([self] + descendants).map(&:name) } }
    end

    # Take a list of filters to be mapped so they can update the query
    # used upon the fulltext search of the ngrams
    def map_query_filters(filters)
      Hash[filters.map do |key, value|
        case value
        when Hash
          if value.key? :any then format_query_filter('$in', key, value[:any])
          elsif value.key? :all then format_query_filter('$all', key, value[:all])
          else raise UnknownFilterQueryOperator, value.keys.join(','), caller end
        else format_query_filter('$all', key, value)
        end
      end]
    end

    def format_query_filter(operator, key, value)
      ['filter_values.%s' % key, { operator => [value].flatten }]
    end
  end

  def update_ngram_index
    self.class.each_fulltext_index do |index_name, fulltext_config, locale|
      if condition = fulltext_config[:update_if]
        case condition
        when Symbol then  next unless send condition
        when String then  next unless instance_eval condition
        when Proc then    next unless condition.call self
        else; next
        end
      end

      # remove existing ngrams from external index
      coll = collection.database[index_name.to_sym]
      removal_query = { 'document_id' => _id }
      removal_query['locale'] = locale if locale
      if Mongoid::Compatibility::Version.mongoid5_or_newer?
        coll.find(removal_query).delete_many
      else
        coll.find(removal_query).remove_all
      end
      # extract ngrams from fields
      ngrams = if fulltext_config.key?(:priorities)
                 FieldScores.calculate(fulltext_config) { |field| send(field) }
               else
                 field_values = fulltext_config[:ngram_fields].flat_map { |field| send(field) }
                 field_values.inject({}) { |accum, item| accum.update(self.class.all_ngrams(item, fulltext_config, false)) }
               end
      next if ngrams.empty?

      # apply filters, if necessary
      filter_values = nil
      if fulltext_config.key?(:filters)
        filter_values = Hash[fulltext_config[:filters].map do |key, value|
          begin
            [key, value.call(self)]
          rescue StandardError
            # Suppress any exceptions caused by filters
          end
        end.compact]
      end
      # insert new ngrams in external index
      index_documents = ngrams.map do |ngram, score|
        index_document = { 'ngram' => ngram, 'document_id' => _id, 'score' => score, 'class' => self.class.name }
        index_document['locale'] = locale if locale
        index_document['filter_values'] = filter_values if fulltext_config.key?(:filters)
        index_document
      end
      if Mongoid::Compatibility::Version.mongoid5_or_newer?
        coll.insert_many(index_documents)
      else
        coll.insert(index_documents)
      end
    end
  end

  def remove_from_ngram_index
    mongoid_fulltext_config.each_pair do |index_name, _fulltext_config|
      coll = collection.database[index_name]
      if Mongoid::Compatibility::Version.mongoid5_or_newer?
        coll.find('document_id' => _id).delete_many
      else
        coll.find('document_id' => _id).remove_all
      end
    end
  end
end
