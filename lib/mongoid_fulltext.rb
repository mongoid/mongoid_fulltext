require 'mongoid_indexes'

module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :mongoid_fulltext_config
  end

  class UnspecifiedIndexError < StandardError; end

  module ClassMethods
  
    def fulltext_search_in(*args)
      self.mongoid_fulltext_config = {} if self.mongoid_fulltext_config.nil?
      options = args.last.is_a?(Hash) ? args.pop : {}
      if options.has_key?(:index_name)
        index_name = options[:index_name]
      else
        index_name = 'mongoid_fulltext.index_%s_%s' % [self.name.downcase, self.mongoid_fulltext_config.count]
      end

      config = { 
        :alphabet => 'abcdefghijklmnopqrstuvwxyz0123456789 ',
        :word_separators => ' ',
        :ngram_width => 3,
        :max_ngrams_to_search => 6,
        :apply_prefix_scoring_to_all_words => true,
        :index_full_words => true,
        :max_candidate_set_size => 1000
      }
      
      config.update(options)

      args = [:to_s] if args.empty?
      config[:ngram_fields] = args
      config[:alphabet] = Hash[config[:alphabet].split('').map{ |ch| [ch,ch] }]
      config[:word_separators] = Hash[config[:word_separators].split('').map{ |ch| [ch,ch] }]
      self.mongoid_fulltext_config[index_name] = config
      
      before_save :update_ngram_index
      before_destroy :remove_from_ngram_index
    end
    
    def create_fulltext_indexes
      self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
        fulltext_search_ensure_indexes(index_name, fulltext_config)
      end
    end

    def fulltext_search_ensure_indexes(index_name, config)
      db = collection.db
      coll = db.collection(index_name)

      # The order of filters matters when the same index is used from two or more collections.
      filter_indexes = (config[:filters] || []).map do |key,value|
        ["filter_values.#{key}", Mongo::ASCENDING]
      end.sort_by { |filter_index| filter_index[0] }
      
      index_definition = [['ngram', Mongo::ASCENDING], ['score', Mongo::DESCENDING]].concat(filter_indexes)

      # Since the definition of the index could have changed, we'll clean up by
      # removing any indexes that aren't on the exact.
      correct_keys = index_definition.map{ |field_def| field_def[0] }
      all_filter_keys = filter_indexes.map{ |field_def| field_def[0] }
      coll.index_information.each do |name, definition|
        keys = definition['key'].keys
        next if !keys.member?('ngram')
        all_filter_keys |= keys.find_all{ |key| key.starts_with?('filter_values.') }
        if keys & correct_keys != correct_keys
          Mongoid.logger.info "Droping #{name} [#{keys & correct_keys} <=> #{correct_keys}]"
          coll.drop_index(name)
        end
      end

      if all_filter_keys.length > filter_indexes.length
        filter_indexes = all_filter_keys.map { |key| [key, Mongo::ASCENDING] }.sort_by { |filter_index| filter_index[0] }
        index_definition = [['ngram', Mongo::ASCENDING], ['score', Mongo::DESCENDING]].concat(filter_indexes)        
      end
      
      Mongoid.logger.info "Ensuring fts_index on #{coll.name}: #{index_definition}"
      coll.ensure_index(index_definition, { :name => 'fts_index' })
      Mongoid.logger.info "Ensuring document_id index on #{coll.name}"
      coll.ensure_index([['document_id', Mongo::ASCENDING]]) # to make removes fast
    end
    
    def fulltext_search(query_string, options={})
      max_results = options.has_key?(:max_results) ? options.delete(:max_results) : 10
      return_scores = options.has_key?(:return_scores) ? options.delete(:return_scores) : false
      if self.mongoid_fulltext_config.count > 1 and !options.has_key?(:index) 
        error_message = '%s is indexed by multiple full-text indexes. You must specify one by passing an :index_name parameter'
        raise UnspecifiedIndexError, error_message % self.name, caller
      end
      index_name = options.has_key?(:index) ? options.delete(:index) : self.mongoid_fulltext_config.keys.first

      # Options hash should only contain filters after this point

      ngrams = all_ngrams(query_string, self.mongoid_fulltext_config[index_name])
      return [] if ngrams.empty?

      # For each ngram, construct the query we'll use to pull index documents and 
      # get a count of the number of index documents containing that n-gram
      ordering = [['score', Mongo::DESCENDING]]
      limit = self.mongoid_fulltext_config[index_name][:max_candidate_set_size]
      coll = collection.db.collection(index_name)
      cursors = ngrams.map do |ngram| 
        query = {'ngram' => ngram[0]}
        query.update(Hash[options.map { |key,value| [ 'filter_values.%s' % key, { '$all' => [ value ].flatten } ] }])
        count = coll.find(query).count
        {:ngram => ngram, :count => count, :query => query}
      end.sort_by!{ |record| record[:count] }

      # Using the queries we just constructed and the n-gram frequency counts we
      # just computed, pull in about *:max_candidate_set_size* candidates by 
      # considering the n-grams in order of increasing frequency. When we've 
      # spent all *:max_candidate_set_size* candidates, pull the top-scoring 
      # *max_results* candidates for each remaining n-gram.
      results_so_far = 0
      candidates_list = cursors.map do |doc|
        next if doc[:count] == 0
        query_options = {}
        if results_so_far >= limit
          query_options = {:sort => ordering, :limit => max_results}
        elsif doc[:count] > limit - results_so_far
          query_options = {:sort => ordering, :limit => limit - results_so_far}
        end
        results_so_far += doc[:count]
        ngram_score = ngrams[doc[:ngram][0]]
        Hash[coll.find(doc[:query], query_options).map do |candidate|
               [candidate['document_id'], 
                {clazz: candidate['class'], score: candidate['score'] * ngram_score}]
             end]
      end.compact
      
      # Finally, score all candidates by matching them up with other candidates that are
      # associated with the same document. This is similar to how you might process a
      # boolean AND query, except that with an AND query, you'd stop after considering
      # the first candidate list and matching its candidates up with candidates from other
      # lists, whereas here we want the search to be a little fuzzier so we'll run through
      # all candidate lists, removing candidates as we match them up.
      all_scores = []
      while !candidates_list.empty?
        candidates = candidates_list.pop
        scores = candidates.map do |candidate_id, data|
          {:id => candidate_id, 
           :clazz => data[:clazz], 
           :score => data[:score] + candidates_list.map{ |others| (others.delete(candidate_id) || {score: 0})[:score] }.sum
           }
        end
        all_scores.concat(scores)
      end
      all_scores.sort_by!{ |document| -document[:score] }

      instantiate_mapreduce_results(all_scores[0..max_results-1], { :return_scores => return_scores })
    end
    
    def instantiate_mapreduce_result(result)
      result[:clazz].constantize.find(:first, :conditions => {'_id' => result[:id]})
    end
    
    def instantiate_mapreduce_results(results, options)
      if (options[:return_scores])
        results.map { |result| [ instantiate_mapreduce_result(result), result[:score] ] }.find_all { |result| ! result[0].nil? }
      else
        results.map { |result| instantiate_mapreduce_result(result) }.compact
      end
    end

    # returns an [ngram, score] [ngram, position] pair
    def all_ngrams(str, config, bound_number_returned = true)
      return {} if str.nil? or str.length < config[:ngram_width]
      filtered_str = str.downcase.split('').map{ |ch| config[:alphabet][ch] }.compact.join('')
      
      if bound_number_returned
        step_size = [((filtered_str.length - config[:ngram_width]).to_f / config[:max_ngrams_to_search]).ceil, 1].max
      else
        step_size = 1
      end
      
      # array of ngrams
      ngram_ary = (0..filtered_str.length - config[:ngram_width]).step(step_size).map do |i|
        if i == 0 or (config[:apply_prefix_scoring_to_all_words] and \
                      config[:word_separators].has_key?(filtered_str[i-1].chr))
          score = Math.sqrt(1 + 1.0/filtered_str.length)
        else
          score = Math.sqrt(2.0/filtered_str.length)
        end
        [filtered_str[i..i+config[:ngram_width]-1], score]
      end
      
      if (config[:index_full_words])
        filtered_str.split(Regexp.compile(config[:word_separators].keys.join)).each do |word|
          if word.length >= config[:ngram_width]
            ngram_ary << [ word, 1 ]
          end
        end
      end
      
      ngram_hash = {}
      
      # deduplicate, and keep the highest score
      ngram_ary.each do |ngram, score, position|        
        ngram_hash[ngram] = [ngram_hash[ngram] || 0, score].max
      end
      
      ngram_hash
    end
    
    def remove_from_ngram_index
      self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
        coll = collection.db.collection(index_name)
        coll.remove({'class' => self.name})
      end
    end
    
    def update_ngram_index
      self.all.each do |model|
        model.update_ngram_index
      end
    end
    
  end

  def update_ngram_index
    self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
      # remove existing ngrams from external index
      coll = collection.db.collection(index_name)
      coll.remove({'document_id' => self._id})
      # extract ngrams from fields
      field_values = fulltext_config[:ngram_fields].map { |field| self.send(field) }
      ngrams = field_values.inject({}) { |accum, item| accum.update(self.class.all_ngrams(item, fulltext_config, false))}
      return if ngrams.empty?
      # apply filters, if necessary
      filter_values = nil
      if fulltext_config.has_key?(:filters)
        filter_values = Hash[fulltext_config[:filters].map do |key,value|
          begin 
            [key, value.call(self)] 
          rescue 
            # Suppress any exceptions caused by filters
          end
        end.compact]
      end
      # insert new ngrams in external index
      ngrams.each_pair do |ngram, score|
        index_document = {'ngram' => ngram, 'document_id' => self._id, 'score' => score, 'class' => self.class.name}
        index_document['filter_values'] = filter_values if fulltext_config.has_key?(:filters)
        coll.insert(index_document)
      end
    end
  end

  def remove_from_ngram_index
    self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
      coll = collection.db.collection(index_name)
      coll.remove({'document_id' => self._id})
    end
  end

end
