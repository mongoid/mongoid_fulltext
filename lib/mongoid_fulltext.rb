module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :ngram_fields, :ngram_width, :ngram_alphabet, :max_ngrams_to_search, \
                   :fulltext_prefix_score, :fulltext_infix_score, :index_collection
  end

  module ClassMethods

    def fulltext_search_in(*args)
      if args.last.is_a?(Hash) and args.last.has_key?(:index_collection)
        self.index_collection = args.pop[:index_collection]
      end
      self.ngram_width = 3
      self.ngram_alphabet = Hash['abcdefghijklmnopqrstuvwxyz0123456789 '.split('').map{ |ch| [ch,ch] }]
      self.max_ngrams_to_search = 6
      self.ngram_fields = args
      self.fulltext_prefix_score = 3
      self.fulltext_infix_score = 1
      if self.index_collection.nil?
        field :_ngrams, :type => Hash
        field :_ngrams_weight, :type => Integer
        index :_ngrams
        before_save :update_internal_ngrams
      else
        #TODO: ensure index on self.index_collection
        before_save :update_external_ngrams
      end
    end

    def fulltext_search(query, max_results=nil)
      if self.index_collection.nil? 
        fulltext_search_internal(query, max_results)
      else
        fulltext_search_external(query, max_results)
      end
    end

    def fulltext_search_internal(query, max_results=nil)
      ngrams = all_ngrams(query)
      return self.criteria if ngrams.empty?
      query = {'$or' => ngrams.map{ |ngram| {'_ngrams.%s' % ngram => {'$gte' => 0 }}}}
      map = <<-EOS
        function() {
          var score = 0;
          for (i in ngrams) {
            var match_val = this._ngrams[ngrams[i]]
            if (match_val != null) {
              if (i == 0) {
                score += match_val //prefix match
              } else {
                score += 1
              }  
            }
          }
          emit(this, score/this._ngrams_weight)
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
      options = {:scope => {:ngrams => ngrams }, :query => query}
      results = collection.map_reduce(map, reduce, options).find().sort(['value',-1])
      results = results.limit(max_results) if !max_results.nil?
      results.map{ |result| self.instantiate(result['_id']) }
    end

    def fulltext_search_external(query, max_results=nil)
      #TODO
    end
    
    def all_ngrams(str, bound_number_returned=true)
      return [] if str.nil? or str.length < self.ngram_width
      filtered_str = str.downcase.split('').map{ |ch| self.ngram_alphabet[ch] }.find_all{ |ch| !ch.nil? }.join('')
      if bound_number_returned
        step_size = [((filtered_str.length - self.ngram_width).to_f / self.max_ngrams_to_search).ceil, 1].max
      else
        step_size = 1
      end
      (0..filtered_str.length - self.ngram_width).step(step_size).map { |i| filtered_str[i..i+self.ngram_width-1] }
    end

  end

  protected

  def update_internal_ngrams
    field_values = self.ngram_fields.map { |field| self.send(field) }
    ngrams = field_values.map { |value| self.class.all_ngrams(value, false) }.flatten
    if ngrams.empty?
      self._ngrams = {}
      return
    end
    first, rest = ngrams.first, ngrams[1..-1]
    self._ngrams = Hash[rest.map { |ngram| [ngram, self.fulltext_infix_score] }]
    self._ngrams_weight = field_values.inject(0) { |accum, item| accum += item.length }
    self._ngrams[first] = self.fulltext_prefix_score
  end

  def update_external_ngrams
    #TODO
  end
  
end
