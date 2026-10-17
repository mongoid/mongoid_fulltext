module Mongoid
  module FullTextSearch
    # Combines weighted field contributions without counting duplicate array elements.
    module FieldScores
      module_function

      def configure(config, fields)
        return unless config.key?(:priorities) || config.key?(:score_aggregation)

        priorities = config.fetch(:priorities, {})
        raise ArgumentError, ':priorities must be a Hash' unless priorities.is_a?(Hash)

        normalized = {}
        priorities.each do |field, weight|
          raise ArgumentError, ':priorities keys must name indexed fields' unless (field.is_a?(String) || field.is_a?(Symbol)) && fields.map(&:to_s).include?(field.to_s)
          raise ArgumentError, ':priorities values must be positive finite numbers' unless weight.is_a?(Numeric) && weight.real? && weight.to_f.finite? && weight.to_f > 0
          raise ArgumentError, ':priorities contains duplicate field names' if normalized.key?(field.to_s)

          normalized[field.to_s] = weight.to_f
        end
        aggregation = config.fetch(:score_aggregation, :max)
        raise ArgumentError, ':score_aggregation must be :max or :sum' unless %i[max sum].include?(aggregation)

        config[:priorities] = normalized
        config[:score_aggregation] = aggregation
      end

      def calculate(config)
        config[:ngram_fields].map(&:to_s).uniq.each_with_object({}) do |field, scores|
          field_scores = [yield(field)].flatten(1).inject({}) do |terms, value|
            terms.merge(Ngrams.calculate(value, config, false)) { |_term, first, second| [first, second].max }
          end
          weight = config[:priorities].fetch(field.to_s, 1.0)
          field_scores.each do |term, score|
            weighted = score * weight
            scores[term] = if !scores.key?(term)
                             weighted
                           elsif config[:score_aggregation] == :sum
                             scores[term] + weighted
                           else
                             [scores[term], weighted].max
                           end
          end
        end
      end
    end
  end
end
