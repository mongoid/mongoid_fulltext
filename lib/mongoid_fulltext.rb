module Mongoid::FullTextSearch
  extend ActiveSupport::Concern

  included do
    cattr_accessor :mongoid_fulltext_config
  end

  module ClassMethods

    def fulltext_search_in(*args)
      self.mongoid_fulltext_config = {} if self.mongoid_fulltext_config.nil?
      options = args.last.is_a?(Hash) ? args.pop : {}
      if options.has_key?(:index_name)
        index_name = options[:index_name]
      else
        index_name = 'mongoid_fulltext.index_%s_%s' % [self.name.downcase, self.mongoid_fulltext_config.count]
      end

      config = {:alphabet => 'abcdefghijklmnopqrstuvwxyz0123456789 ',
                :word_separators => ' ',
                :ngram_width => 3,
                :max_ngrams_to_search => 6,
                :apply_prefix_scoring_to_all_words => true}
      config.update(options)

      args = [:to_s] if args.empty?
      config[:ngram_fields] = args
      config[:alphabet] = Hash[config[:alphabet].split('').map{ |ch| [ch,ch] }]
      config[:word_separators] = Hash[config[:word_separators].split('').map{ |ch| [ch,ch] }]

      self.mongoid_fulltext_config[index_name] = config

      coll = collection.db.collection(index_name)
      coll.ensure_index([['ngram', Mongo::ASCENDING]])

      before_save :update_ngram_index
      before_destroy :remove_from_ngram_index
    end

    def fulltext_search(query_string, options={})
      max_results = options.has_key?(:max_results) ? options[:max_results] : 10
      # if self.mongoid_fulltext_config.count > 1 and !options.has_key?(:index) raise an exception
      index_name = options.has_key?(:index) ? options[:index] : self.mongoid_fulltext_config.keys.first
      ngrams = all_ngrams(query_string, self.mongoid_fulltext_config[index_name])
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
      mr_options = {:scope => {:ngrams => ngrams }, :query => query, :raw => true}
      coll = collection.db.collection(index_name)
      result_collection = coll.map_reduce(map, reduce, mr_options)['result']
      results = collection.db.collection(result_collection).find.sort(['value.score',-1])
      results = results.limit(max_results) if !max_results.nil?
      models = results.map { |result| Object::const_get(result['value']['class']).find(:first, :conditions => {:id => result['_id']}) }\
                      .find_all { |result| !result.nil? }
      collection.db.collection(result_collection).drop
      models
    end
    
    def all_ngrams(str, config, bound_number_returned=true)
      return {} if str.nil? or str.length < config[:ngram_width]
      filtered_str = str.downcase.split('').map{ |ch| config[:alphabet][ch] }.find_all{ |ch| !ch.nil? }.join('')
      if bound_number_returned
        step_size = [((filtered_str.length - config[:ngram_width]).to_f / config[:max_ngrams_to_search]).ceil, 1].max
      else
        step_size = 1
      end
      Hash[(0..filtered_str.length - config[:ngram_width]).step(step_size).map do |i|
        if i == 0 or (config[:apply_prefix_scoring_to_all_words] and \
                      config[:word_separators].has_key?(filtered_str[i-1]))
          score = Math.sqrt(1 + 1.0/filtered_str.length)
        else
          score = Math.sqrt(2.0/filtered_str.length)
        end
        [filtered_str[i..i+config[:ngram_width]-1], score]
      end]
    end

  end

  protected

  def update_ngram_index
    self.mongoid_fulltext_config.each_pair do |index_name, fulltext_config|
      # remove existing ngrams from external index
      coll = collection.db.collection(index_name)
      coll.remove({'document_id' => self._id})
      # extract ngrams from fields
      field_values = fulltext_config[:ngram_fields].map { |field| self.send(field) }
      ngrams = field_values.inject({}) { |accum, item| accum.update(self.class.all_ngrams(item, fulltext_config, false))}
      return if ngrams.empty?
      # insert new ngrams in external index
      ngrams.each_pair do |ngram, score|
        coll.insert({'ngram' => ngram, 'document_id' => self._id, 'score' => score, 'class' => self.class.name})
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
