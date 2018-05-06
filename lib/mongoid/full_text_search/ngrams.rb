module Mongoid
  module FullTextSearch
    module Ngrams
      extend ActiveSupport::Concern

      module ClassMethods
        def all_ngrams(str, config, bound_number_returned = true)
          return {} if str.nil?

          if config[:remove_accents]
            if defined?(UnicodeUtils)
              str = UnicodeUtils.nfkd(str)
            elsif defined?(DiacriticsFu)
              str = DiacriticsFu.escape(str)
            end
          end

          # Remove any characters that aren't in the alphabet and aren't word separators
          filtered_str = str.mb_chars.downcase.to_s.split('').find_all { |ch| config[:alphabet][ch] || config[:word_separators][ch] }.join('')

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
            if i == 0 || (config[:apply_prefix_scoring_to_all_words] && \
                          config[:word_separators].key?(filtered_str[i - 1].chr))
              score = Math.sqrt(1 + 1.0 / filtered_str.length)
            else
              score = Math.sqrt(2.0 / filtered_str.length)
            end
            { ngram: filtered_str[i..i + config[:ngram_width] - 1], score: score }
          end

          # If an ngram appears multiple times in the query string, keep the max score
          ngram_array = ngram_array.group_by { |h| h[:ngram] }.map { |key, values| { ngram: key, score: values.map { |v| v[:score] }.max } }

          if config[:index_short_prefixes] || config[:index_full_words]
            split_regex_def = config[:word_separators].keys.map { |k| Regexp.escape(k) }.join
            split_regex = Regexp.compile("[#{split_regex_def}]")
            all_words = filtered_str.split(split_regex)
          end

          # Add 'short prefix' records to the array: prefixes of the string that are length (ngram_width - 1)
          if config[:index_short_prefixes]
            prefixes_seen = {}
            all_words.each do |word|
              next if word.length < config[:ngram_width] - 1
              prefix = word[0...config[:ngram_width] - 1]
              if prefixes_seen[prefix].nil? && (config[:stop_words][word].nil? || word == filtered_str)
                ngram_array << { ngram: prefix, score: 1 + 1.0 / filtered_str.length }
                prefixes_seen[prefix] = true
              end
            end
          end

          # Add records to the array of ngrams for each full word in the string that isn't a stop word
          if config[:index_full_words]
            full_words_seen = {}
            all_words.each do |word|
              if word.length > 1 && full_words_seen[word].nil? && (config[:stop_words][word].nil? || word == filtered_str)
                ngram_array << { ngram: word, score: 1 + 1.0 / filtered_str.length }
                full_words_seen[word] = true
              end
            end
          end

          # If an ngram appears as any combination of full word, short prefix, and ngram, keep the sum of the two scores
          Hash[ngram_array.group_by { |h| h[:ngram] }.map { |key, values| [key, values.map { |v| v[:score] }.sum] }]
        end

        def remove_from_ngram_index
          mongoid_fulltext_config.each_pair do |index_name, _fulltext_config|
            ::I18n.available_locales.each do |locale|
              coll = collection.database[localized_index_name(index_name, locale)]
              if Mongoid::Compatibility::Version.mongoid5_or_newer?
                coll.find('class' => name).delete_many
              else
                coll.find('class' => name).remove_all
              end
            end
          end
        end
      end
    end
  end
end
