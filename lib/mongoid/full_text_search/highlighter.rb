require 'cgi'
require_relative 'ngrams'

module Mongoid
  module FullTextSearch
    # Adds display values to ranked search results without modifying documents.
    module HighlightedSearch
      def fulltext_search_with_highlights(query_string, options = {}, &block)
        search_options = options.dup
        fields = search_options.delete(:fields)
        index = search_options.fetch(:index) do
          raise UnspecifiedIndexError, 'Specify :index for a model with multiple full-text indexes' if mongoid_fulltext_config.length > 1

          mongoid_fulltext_config.keys.first
        end
        indexed_fields = mongoid_fulltext_config.fetch(index)[:ngram_fields]
        fields = (fields.nil? ? indexed_fields : Array(fields)).map(&:to_sym)
        raise ArgumentError, ':fields must contain indexed field names' unless (fields - indexed_fields.map(&:to_sym)).empty?

        search_options[:return_scores] = true
        fulltext_search(query_string, search_options).map do |document, score|
          highlights = document.fulltext_highlights(query_string, index: index, fields: fields, &block)
          HighlightedResult.new(document, highlights, score)
        end
      end
    end

    # Highlights current text without storing positional index metadata.
    module Highlighter
      module_function

      def highlight(text, query, config, &block)
        return nil if text.nil?

        terms = Ngrams.calculate(query, config).keys.reject(&:empty?)
        return CGI.escapeHTML(text) if terms.empty?

        normalized, positions = normalized_positions(text, config)
        indexed_terms = Ngrams.calculate(text, config, false)
        ranges = matching_ranges(normalized, terms & indexed_terms.keys, config).map do |start, finish|
          [positions[start][0], positions[finish - 1][1]]
        end
        merged = merge_ranges(ranges)
        render(text, merged, &block)
      end

      def normalized_positions(text, config)
        positions = []
        offset = 0
        UnicodeUtils.each_grapheme(text) do |grapheme|
          part = Ngrams.normalized_text(grapheme, config)
          part.length.times { positions << [offset, offset + grapheme.length] }
          offset += grapheme.length
        end
        # Whole-string case conversion can be contextual; preserve its actual characters.
        whole = Ngrams.normalized_text(text, config)
        raise ArgumentError, 'Normalization changed character counts across grapheme boundaries' unless whole.length == positions.length

        [whole, positions]
      end

      def matching_ranges(text, terms, config)
        separators = config[:word_separators]
        terms.each_with_object([]) do |term, ranges|
          offset = 0
          while (start = text.index(term, offset))
            finish = start + term.length
            word_start = start.zero? || separators.key?(text[start - 1])
            word_end = finish == text.length || separators.key?(text[finish])
            window = term.length == config[:ngram_width]
            prefix = config[:index_short_prefixes] && term.length == config[:ngram_width] - 1 && word_start
            word = config[:index_full_words] && word_start && word_end
            ranges << [start, finish] if window || prefix || word
            offset = start + 1
          end
        end
      end

      def merge_ranges(ranges)
        ranges.sort.each_with_object([]) do |range, merged|
          if !merged.empty? && range[0] <= merged.last[1]
            merged.last[1] = [merged.last[1], range[1]].max
          else
            merged << range.dup
          end
        end
      end

      def render(text, ranges)
        html = ''
        cursor = 0
        ranges.each do |first, last|
          html << CGI.escapeHTML(text[cursor...first])
          match = CGI.escapeHTML(text[first...last])
          html << (block_given? ? yield(match) : "<b>#{match}</b>")
          cursor = last
        end
        html << CGI.escapeHTML(text[cursor..-1])
      end

      private_class_method :normalized_positions, :matching_ranges, :merge_ranges, :render
    end
  end
end
