require 'mongoid_indexes'
require 'unicode_utils'
require 'cgi'

module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :mongoid_fulltext_config
  end

  class UnspecifiedIndexError < StandardError; end
  class UnknownFilterQueryOperator < StandardError; end

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
        :word_separators => "-_ \n\t",
        :ngram_width => 3,
        :max_ngrams_to_search => 6,
        :apply_prefix_scoring_to_all_words => true,
        :index_full_words => true,
        :index_short_prefixes => false,
        :max_candidate_set_size => 1000,
        :remove_accents => true,
        :reindex_immediately => true,
        :stop_words => Hash[['i', 'a', 's', 't', 'me', 'my', 'we', 'he', 'it', 'am', 'is', 'be', 'do', 'an', 'if',
                             'or', 'as', 'of', 'at', 'by', 'to', 'up', 'in', 'on', 'no', 'so', 'our', 'you', 'him',
                             'his', 'she', 'her', 'its', 'who', 'are', 'was', 'has', 'had', 'did', 'the', 'and',
                             'but', 'for', 'out', 'off', 'why', 'how', 'all', 'any', 'few', 'nor', 'not', 'own',
                             'too', 'can', 'don', 'now', 'ours', 'your', 'hers', 'they', 'them', 'what', 'whom',
                             'this', 'that', 'were', 'been', 'have', 'does', 'with', 'into', 'from', 'down', 'over',
                             'then', 'once', 'here', 'when', 'both', 'each', 'more', 'most', 'some', 'such', 'only',
                             'same', 'than', 'very', 'will', 'just', 'yours', 'their', 'which', 'these', 'those',
                             'being', 'doing', 'until', 'while', 'about', 'after', 'above', 'below', 'under',
                             'again', 'there', 'where', 'other', 'myself', 'itself', 'theirs', 'having', 'during',
                             'before', 'should', 'himself', 'herself', 'because', 'against', 'between', 'through',
                             'further', 'yourself', 'ourselves', 'yourselves', 'themselves'].map{ |x| [x,true] }]
      }
      
      config.update(options)

      args = [:to_s] if args.empty?
      config[:ngram_fields] = args
      config[:alphabet] = Hash[config[:alphabet].split('').map{ |ch| [ch,ch] }]
      config[:word_separators] = Hash[config[:word_separators].split('').map{ |ch| [ch,ch] }]
      self.mongoid_fulltext_config[index_name] = config
      
      before_save(:update_ngram_index) if config[:reindex_immediately]
      before_destroy :remove_from_ngram_index
    end
    
    def create_fulltext_indexes
      return unless self.mongoid_fulltext_config
      self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
        fulltext_search_ensure_indexes(index_name, fulltext_config)
      end
    end

    def fulltext_search_ensure_indexes(index_name, config)
      db = collection.database
      coll = db[index_name]

      # The order of filters matters when the same index is used from two or more collections.
      filter_indexes = (config[:filters] || []).map do |key,value|
        ["filter_values.#{key}", 1]
      end.sort_by { |filter_index| filter_index[0] }
      
      index_definition = [['ngram', 1], ['score', -1]].concat(filter_indexes)

      # Since the definition of the index could have changed, we'll clean up by
      # removing any indexes that aren't on the exact.
      correct_keys = index_definition.map{ |field_def| field_def[0] }
      all_filter_keys = filter_indexes.map{ |field_def| field_def[0] }
      coll.indexes.each do |idef|
        keys = idef['key'].keys
        next if !keys.member?('ngram')
        all_filter_keys |= keys.find_all{ |key| key.starts_with?('filter_values.') }
        if keys & correct_keys != correct_keys
          Mongoid.logger.info "Dropping #{idef['name']} [#{keys & correct_keys} <=> #{correct_keys}]" if Mongoid.logger
          coll.indexes.drop(idef['key'])
        end
      end

      if all_filter_keys.length > filter_indexes.length
        filter_indexes = all_filter_keys.map {|key| [key, 1] }.sort_by { |filter_index| filter_index[0] }
        index_definition = [['ngram', 1], ['score', -1]].concat(filter_indexes)
      end
      
      Mongoid.logger.info "Ensuring fts_index on #{coll.name}: #{index_definition}" if Mongoid.logger
      coll.indexes.create(Hash[index_definition], { :name => 'fts_index' })

      Mongoid.logger.info "Ensuring document_id index on #{coll.name}" if Mongoid.logger
      coll.indexes.create('document_id' => 1) # to make removes fast
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
      
      ordering_field = options.has_key?(:order_field) ? options.delete(:order_field) : 'score'
      ordering_type = options.has_key?(:order_type) ? options.delete(:order_type) : -1
      ordering = {}
      ordering[ordering_field] = ordering_type
      limit = self.mongoid_fulltext_config[index_name][:max_candidate_set_size]
      coll = collection.database[index_name]
      cursors = ngrams.map do |ngram|
        query = {'ngram' => ngram[0]}
        query.update(map_query_filters options)
        count = coll.find(query).count
        {:ngram => ngram, :count => count, :query => query}
      end.sort!{ |record1, record2| record1[:count] <=> record2[:count] }

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
                {:clazz => candidate['class'], :score => candidate['score'] * ngram_score}]
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
           :score => data[:score] + candidates_list.map{ |others| (others.delete(candidate_id) || {:score => 0})[:score] }.sum
           }
        end
        all_scores.concat(scores)
      end
      all_scores.sort!{ |document1, document2| -document1[:score] <=> -document2[:score] }
      instantiate_mapreduce_results(all_scores[0..max_results-1], { :return_scores => return_scores })
    end
    
    def instantiate_mapreduce_result(result)
      result[:clazz].constantize.find(result[:id])
    end
    
    def instantiate_mapreduce_results(results, options)
      if (options[:return_scores])
        results.map { |result| [ instantiate_mapreduce_result(result), result[:score] ] }.find_all { |result| ! result[0].nil? }
      else
        results.map { |result| instantiate_mapreduce_result(result) }.compact
      end
    end

    def all_ngrams(str, config, bound_number_returned = true)
      return {} if str.nil?

      if config[:remove_accents]
        if defined?(UnicodeUtils)
          str = UnicodeUtils.nfkd(str)
        elsif defined?(DiacriticsFu)
          str = DiacriticsFu::escape(str)
        end
      end

      # Remove any characters that aren't in the alphabet and aren't word separators
      filtered_str = str.mb_chars.downcase.to_s.split('').find_all{ |ch| config[:alphabet][ch] or config[:word_separators][ch] }.join('')
      
      # Figure out how many ngrams to extract from the string. If we can't afford to extract all ngrams,
      # step over the string in evenly spaced strides to extract ngrams. For example, to extract 3 3-letter
      # ngrams from 'abcdefghijk', we'd want to extract 'abc', 'efg', and 'ijk'.
      if bound_number_returned
        step_size = [((filtered_str.length - config[:ngram_width]).to_f / config[:max_ngrams_to_search]).ceil, 1].max
      else
        step_size = 1
      end
      
      # Create an array of records of the form {:ngram => x, :score => y} for all ngrams that occur in the
      # input string using the step size that we just computed. Let score(x,y) be the score of string x
      # compared with string y - assigning scores to ngrams with the square root-based scoring function
      # below and multiplying scores of matching ngrams together yields a score function that has the
      # property that score(x,y) > score(x,z) for any string z containing y and score(x,y) > score(x,z)
      # for any string z contained in y.
      ngram_array = (0..filtered_str.length - config[:ngram_width]).step(step_size).map do |i|
        if i == 0 or (config[:apply_prefix_scoring_to_all_words] and \
                      config[:word_separators].has_key?(filtered_str[i-1].chr))
          score = Math.sqrt(1 + 1.0/filtered_str.length)
        else
          score = Math.sqrt(2.0/filtered_str.length)
        end
        {:ngram => filtered_str[i..i+config[:ngram_width]-1], :score => score}
      end

      # If an ngram appears multiple times in the query string, keep the max score
      ngram_array = ngram_array.group_by{ |h| h[:ngram] }.map{ |key, values| {:ngram => key, :score => values.map{ |v| v[:score] }.max} }
      
      if config[:index_short_prefixes] or config[:index_full_words]
        split_regex_def = config[:word_separators].keys.map{ |k| Regexp.escape(k) }.join
        split_regex = Regexp.compile("[#{split_regex_def}]")
        all_words = filtered_str.split(split_regex)
      end

      # Add 'short prefix' records to the array: prefixes of the string that are length (ngram_width - 1)
      if config[:index_short_prefixes]
        prefixes_seen = {}
        all_words.each do |word|
          next if word.length < config[:ngram_width]-1
          prefix = word[0...config[:ngram_width]-1]
          if prefixes_seen[prefix].nil? and (config[:stop_words][word].nil? or word == filtered_str)
            ngram_array << {:ngram => prefix, :score => 1 + 1.0/filtered_str.length}
            prefixes_seen[prefix] = true
          end
        end
      end

      # Add records to the array of ngrams for each full word in the string that isn't a stop word
      if config[:index_full_words]
        full_words_seen = {}
        all_words.each do |word|
          if word.length > 1 and full_words_seen[word].nil? and (config[:stop_words][word].nil? or word == filtered_str)
            ngram_array << {:ngram => word, :score => 1 + 1.0/filtered_str.length}
            full_words_seen[word] = true
          end
        end
      end

      # If an ngram appears as any combination of full word, short prefix, and ngram, keep the sum of the two scores
      Hash[ngram_array.group_by{ |h| h[:ngram] }.map{ |key, values| [key, values.map{ |v| v[:score] }.sum] }]
    end
    
    def remove_from_ngram_index
      self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
        coll = collection.database[index_name]
        coll.find({'class' => self.name}).remove_all
      end
    end
    
    def update_ngram_index
      self.all.each do |model|
        model.update_ngram_index
      end
    end
    
    private
    # Take a list of filters to be mapped so they can update the query
    # used upon the fulltext search of the ngrams
    def map_query_filters filters
      Hash[filters.map {|key,value|
        case value
          when Hash then
            if value.has_key? :any then format_query_filter('$in',key,value[:any])
            elsif value.has_key? :all then format_query_filter('$all',key,value[:all])
            else raise UnknownFilterQueryOperator, value.keys.join(","), caller end
          else format_query_filter('$all',key,value)
        end
      }]
    end
    def format_query_filter operator, key, value
      ['filter_values.%s' % key, {operator => [value].flatten}]
    end
  end

  def update_ngram_index
    self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
      if condition = fulltext_config[:update_if]
        case condition
        when Symbol;  next unless self.send condition
        when String;  next unless instance_eval condition
        when Proc;    next unless condition.call self
        else;         next
        end
      end

      # remove existing ngrams from external index
      coll = collection.database[index_name.to_sym]
      coll.find({'document_id' => self._id}).remove_all
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
      coll = collection.database[index_name]
      coll.find({'document_id' => self._id}).remove_all
    end
  end

end
