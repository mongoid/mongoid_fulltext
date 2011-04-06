module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :ngram_fields, :ngram_width, :ngram_alphabet, :max_ngrams_to_search, \
                   :fulltext_prefix_score, :fulltext_infix_score, :external_index
  end

  module ClassMethods

    def fulltext_search_in(*args)
      if args.last.is_a?(Hash)
        hash_args = args.pop
        self.external_index = hash_args[:external_index]
      end
      alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789 '
      self.ngram_width = 3
      self.max_ngrams_to_search = 6
      self.ngram_fields = args
      self.fulltext_prefix_score = 3
      self.fulltext_infix_score = 1
      self.ngram_alphabet = Hash[alphabet.split('').map{ |ch| [ch,ch] }]
      field :_ngrams, :type => Hash
      index :_ngrams
      if self.external_index.nil?
        before_save :update_internal_ngrams
      else
        coll = collection.db.collection(self.external_index)
        coll.ensure_index([['ngram', Mongo::ASCENDING]])
        before_save :update_external_ngrams
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
      query = {'$or' => ngrams.map{ |ngram| {'_ngrams.%s' % ngram => {'$gte' => 0 }}}}
      map = <<-EOS
        function() {
          var score = 0;
          for (i in ngrams) {
            var match_val = this._ngrams[ngrams[i]]
            if (match_val != null) {
              score += match_val
            }
          }
          emit(this, score)
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
      score_threshold = (query_string.length > self.ngram_width) ? 1 : 0
      models = results.find_all{ |result| result['value'] > score_threshold }\
                      .map{ |result| self.instantiate(result['_id']) }
      collection.db.collection(result_collection).drop
      models
    end

    def fulltext_search_external(query_string, max_results)
      ngrams = all_ngrams(query_string)
      return [] if ngrams.empty?
      query = {'ngram' => {'$in' => ngrams }}
      map = <<-EOS
        function() {
          emit(this['document_id'], {'class': this['class'], 'score': this['score']})
        }
      EOS
      reduce = <<-EOS
        function(key, values) {
          score = 0
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
      score_threshold = (query_string.length > self.ngram_width) ? 1 : 0
      models = results.find_all{ |result| result['value']['score'] > score_threshold }\
                      .map { |result| Object::const_get(result['value']['class']).find(result['_id']) }
      collection.db.collection(result_collection).drop
      models
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
      return [nil, nil]
    end
    first, rest = ngrams.first, ngrams[1..-1]
    self._ngrams = Hash[rest.map { |ngram| [ngram, self.fulltext_infix_score] }]
    self._ngrams[first] = self.fulltext_prefix_score
    [first, rest]
  end

  def update_external_ngrams
    # remove existing ngrams from external index
    coll = collection.db.collection(self.external_index)
    self._ngrams.each { |ngram| coll.remove({'ngram' => ngram, 'document_id' => self._id})} if !self._ngrams.nil?
    # update internal record so that we can remove these next time we update
    first, rest = update_internal_ngrams
    return if first.nil? and rest.nil?
    # insert new ngrams in external index
    coll.insert({'ngram' => first, 'document_id' => self._id, 
                  'score' => self.fulltext_prefix_score, 'class' => self.class.name})
    rest.each do |ngram| 
      coll.insert({'ngram' => ngram, 'document_id' => self._id, 
                    'score' => self.fulltext_infix_score, 'class' => self.class.name})
    end
  end
  
end
