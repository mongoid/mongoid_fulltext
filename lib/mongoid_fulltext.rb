module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :ngram_fields, :ngram_width, :ngram_alphabet, :max_ngrams_to_search, \
                   :fulltext_prefix_score, :fulltext_infix_score, :external_index, \
                   :word_separators, :apply_prefix_scoring_to_all_words
  end

  module ClassMethods

    def fulltext_search_in(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      def get_option(options, key, default=nil)
        options.has_key?(key) ? options[key] : default
      end

      self.external_index = get_option(options, :external_index)
      # The alphabet is a string containing every symbol we want to index
      alphabet = get_option(options, :alphabet, 'abcdefghijklmnopqrstuvwxyz0123456789 ')
      # A separator is anything that should indicate a split between two words
      separators = get_option(options, :separators, ' ')
      # The n-gram width is the "n" in n-gram: the number of consecutive characters to consider
      self.ngram_width = get_option(options, :ngram_width, 3)
      # max_ngrams_to_search is a ceiling on the number of n-grams to break a search string into
      self.max_ngrams_to_search = get_option(options, :max_ngrams_to_search, 6)
      
      # These scores can be tweaked to change how mongoid_fulltext ranks matches, making it
      # prefer prefix matches over infix matches and vise-versa.
      self.fulltext_prefix_score = get_option(options, :fulltext_prefix_score, 1)
      self.fulltext_infix_score = get_option(options, :fulltext_infix_score, 2)
      self.apply_prefix_scoring_to_all_words = get_option(options, :apply_prefix_scoring_to_all_words, true)

      args = [:to_s] if args.empty?
      self.ngram_fields = args
      self.ngram_alphabet = Hash[alphabet.split('').map{ |ch| [ch,ch] }]
      self.word_separators = Hash[separators.split('').map{ |ch| [ch,ch] }]
      field :_ngrams, :type => Hash
      index :_ngrams
      if self.external_index.nil?
        before_save :update_internal_ngrams
      else
        coll = collection.db.collection(self.external_index)
        coll.ensure_index([['ngram', Mongo::ASCENDING]])
        before_save :update_external_ngrams
        before_destroy :remove_external_ngrams
      end
    end

    def fulltext_search(query, options={})
      if self.external_index.nil? or options[:use_internal_index]
        fulltext_search_internal(query, options[:max_results])
      else
        fulltext_search_external(query, options[:max_results])
      end
    end

    def fulltext_search_internal(query_string, max_results)
      ngrams = all_ngrams(query_string)
      return [] if ngrams.empty?
      query = {'$or' => ngrams.map{ |(ngram, score)| {'_ngrams.%s' % ngram => {'$gte' => 0 }}}}
      map = <<-EOS
        function() {
          var score = 0;
          for (var ngram in ngrams) {
            var match_val = this._ngrams[ngram]
            if (match_val != null) {
              score += match_val * ngrams[ngram]
            }
          }
          emit(this['_id'], score)
        }
      EOS
      reduce = <<-EOS
        function(key, values) {
          score = 0
          for (i in values) {
            score += values[i]
          }
          return(score)
        }
      EOS
      options = {:scope => {:ngrams => ngrams }, :query => query, :raw => true}
      result_collection = collection.map_reduce(map, reduce, options)['result']
      results = collection.db.collection(result_collection).find.sort(['value',-1])
      results = results.limit(max_results) if !max_results.nil?
      models = results.map{ |result| self.find(result['_id']) }
      collection.db.collection(result_collection).drop
      models
    end

    def fulltext_search_external(query_string, max_results)
      ngrams = all_ngrams(query_string)
      return [] if ngrams.empty?
      query = {'ngram' => {'$in' => ngrams.keys}}
      map = <<-EOS
        function() {
          emit(this['document_id'], {'class': this['class'], 'score': this['score']*ngrams[this['ngram']] })
        }
      EOS
      reduce = <<-EOS
        function(key, values) {
          score = 0.0
          for (i in values) {
            score += values[i]['score']
          }
          return({'class': values[0]['class'], 'score': score})
        }
      EOS
      options = {:scope => {:ngrams => ngrams }, :query => query, :raw => true}
      coll = collection.db.collection(self.external_index)
      result_collection = coll.map_reduce(map, reduce, options)['result']
      results = collection.db.collection(result_collection).find.sort(['value.score',-1])
      results = results.limit(max_results) if !max_results.nil?
      models = results.map { |result| Object::const_get(result['value']['class']).find(:first, :conditions => {:id => result['_id']}) }\
                      .find_all { |result| !result.nil? }
      collection.db.collection(result_collection).drop
      models
    end
    
    def all_ngrams(str, bound_number_returned=true)
      return {} if str.nil? or str.length < self.ngram_width
      filtered_str = str.downcase.split('').map{ |ch| self.ngram_alphabet[ch] }.find_all{ |ch| !ch.nil? }.join('')
      if bound_number_returned
        step_size = [((filtered_str.length - self.ngram_width).to_f / self.max_ngrams_to_search).ceil, 1].max
      else
        step_size = 1
      end
      Hash[(0..filtered_str.length - self.ngram_width).step(step_size).map do |i|
        if i == 0 or (self.apply_prefix_scoring_to_all_words and \
                      self.word_separators.has_key?(filtered_str[i-1]))
          score = Math.sqrt(self.fulltext_prefix_score + 1.0/filtered_str.length)
        else
          score = Math.sqrt(self.fulltext_infix_score/Float(filtered_str.length))
        end
        [filtered_str[i..i+self.ngram_width-1], score]
      end]
    end

  end

  protected

  def update_internal_ngrams
    field_values = self.ngram_fields.map { |field| self.send(field) }
    self._ngrams = field_values.inject({}) { |accum, item| accum.update(self.class.all_ngrams(item, false))}
  end

  def update_external_ngrams
    # remove existing ngrams from external index
    coll = collection.db.collection(self.external_index)
    coll.remove({'document_id' => self._id})
    # update internal record so that we can remove these next time we update
    ngrams = update_internal_ngrams
    return if ngrams.empty?
    # insert new ngrams in external index
    ngrams.each_pair do |ngram, score|
      coll.insert({'ngram' => ngram, 'document_id' => self._id, 'score' => score, 'class' => self.class.name})
    end
  end

  def remove_external_ngrams
    coll = collection.db.collection(self.external_index)
    coll.remove({'document_id' => self._id})
  end

end
