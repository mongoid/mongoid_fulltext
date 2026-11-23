require 'active_support'
require 'active_support/core_ext/enumerable'
require 'active_support/core_ext/string/multibyte'
require 'unicode_utils'

module Mongoid
  module FullTextSearch
    # Calculates query and document ngram scores without accessing persistence.
    module Ngrams
      module_function

      def calculate(str, config, bound_number_returned = true)
        return {} if str.nil?

        filtered_str = normalize(str, config)
        ngram_array = sliding_windows(filtered_str, config, bound_number_returned)

        # Repeated windows contribute their maximum score, not their sum.
        ngram_array = ngram_array.group_by { |h| h[:ngram] }.map do |key, values|
          { ngram: key, score: values.map { |v| v[:score] }.max }
        end

        if config[:index_short_prefixes] || config[:index_full_words]
          split_regex_def = config[:word_separators].keys.map { |k| Regexp.escape(k) }.join
          all_words = filtered_str.split(Regexp.compile("[#{split_regex_def}]"))
          ngram_array.concat(short_prefixes(all_words, filtered_str, config)) if config[:index_short_prefixes]
          ngram_array.concat(full_words(all_words, filtered_str, config)) if config[:index_full_words]
        end

        # Window, prefix, and full-word contributions add to the final score.
        Hash[ngram_array.group_by { |h| h[:ngram] }.map { |key, values| [key, values.map { |v| v[:score] }.sum] }]
      end

      def normalized_text(str, config)
        normalize(str, config)
      end

      def normalize(str, config)
        if config[:remove_accents]
          if defined?(UnicodeUtils)
            str = UnicodeUtils.nfkd(str)
          elsif defined?(DiacriticsFu)
            str = DiacriticsFu.escape(str)
          end
        end

        alphabet = config[:alphabet]
        str.mb_chars.downcase.to_s.split('').find_all do |ch|
          (alphabet.is_a?(Regexp) ? alphabet =~ ch : alphabet[ch]) || config[:word_separators][ch]
        end.join('')
      end

      def sliding_windows(str, config, bound_number_returned)
        last_start = str.length - config[:ngram_width]
        ngram_count = last_start + 1
        ngram_count = [ngram_count, config[:max_ngrams_to_search]].min if bound_number_returned

        # Sample both endpoints: three windows from 'abcdefghijk' are 'abc', 'efg', 'ijk'.
        (0...ngram_count).map do |sample|
          i = ngram_count == 1 ? 0 : (sample * last_start.to_f / (ngram_count - 1)).round
          score = if i.zero? || (config[:apply_prefix_scoring_to_all_words] && \
                        config[:word_separators].key?(str[i - 1].chr))
                    Math.sqrt(1 + 1.0 / str.length)
                  else
                    Math.sqrt(2.0 / str.length)
                  end
          { ngram: str[i..i + config[:ngram_width] - 1], score: score }
        end
      end

      def short_prefixes(words, str, config)
        prefixes_seen = {}
        words.each_with_object([]) do |word, records|
          next if word.length < config[:ngram_width] - 1

          prefix = word[0...config[:ngram_width] - 1]
          if prefixes_seen[prefix].nil? && (config[:stop_words][word].nil? || word == str)
            records << { ngram: prefix, score: 1 + 1.0 / str.length }
            prefixes_seen[prefix] = true
          end
        end
      end

      def full_words(words, str, config)
        full_words_seen = {}
        words.each_with_object([]) do |word, records|
          if word.length > 1 && full_words_seen[word].nil? && (config[:stop_words][word].nil? || word == str)
            records << { ngram: word, score: 1 + 1.0 / str.length }
            full_words_seen[word] = true
          end
        end
      end

      private_class_method :normalize, :sliding_windows, :short_prefixes, :full_words
    end
  end
end
