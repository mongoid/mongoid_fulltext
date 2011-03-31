module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :ngram_fields, :ngram_width, :ngram_alphabet, :max_ngrams_to_search, :fulltext_prefix_score, :fulltext_infix_score
  end

  module ClassMethods

    def fulltext_search_in(*args)
      self.ngram_width = 3
      self.ngram_alphabet = Hash['abcdefghijklmnopqrstuvwxyz0123456789 '.split('').map{ |ch| [ch,ch] }]
      self.max_ngrams_to_search = 6
      self.ngram_fields = args
      self.fulltext_prefix_score = 3
      self.fulltext_infix_score = 1
      field :_ngrams, :type => Hash
      index :_ngrams
      before_save :extract_ngrams
    end

    def fulltext_search(query)
      ngrams = all_ngrams(query)
      return self.criteria if ngrams.empty?
      query = {'$or' => ngrams.map{ |ngram| {'_ngrams.%s' % ngram => {'$gte' => 0 }}}}
      map = <<-EOS
        function() {
          var score = 0;
          for (i in ngrams) {
            ngram_score = this._ngrams[ngrams[i]];
            if (ngram_score != null) {
              score += ngram_score;
            }
          }
          if (score > 0) {
            emit(this._id, score)
          }
        }
      EOS
      reduce = <<-EOS
        function(key, values) {
          return(values[0])
        }
      EOS
      options = {:scope => {:ngrams => ngrams}, :query => query}
      ids = collection.map_reduce(map, reduce, options).find().sort(['value',-1]).map{ |result| result['_id'] }
      self.where(:_id.in => ids)
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

  def extract_ngrams
    ngrams = self.ngram_fields.map { |field| Artwork.all_ngrams(self.send(field), false) }.flatten
    if ngrams.empty?
      self._ngrams = {}
      return
    end
    first, rest = ngrams.first, ngrams[1..-1]
    self._ngrams = Hash[rest.map { |ngram| [ngram, self.fulltext_infix_score] }]
    self._ngrams[first] = self.fulltext_prefix_score
  end
  
end
