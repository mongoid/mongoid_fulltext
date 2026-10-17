class WeightedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  field :description, type: String
  field :tags, type: Array
  fulltext_search_in :title, :description, :tags, index_name: 'weighted_max',
                                                  priorities: { title: 10, 'description' => 5 }
  fulltext_search_in :tags, :description, :title, index_name: 'weighted_sum',
                                                  priorities: { title: 10, description: 5 }, score_aggregation: :sum
end

class WeightedComputedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  fulltext_search_in :title, :search_text, priorities: { search_text: 2.5 }, score_aggregation: :sum

  def search_text
    title
  end
end

class WeightedLocalizedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String, localize: true
  field :description, type: String
  fulltext_search_in :title, :description, priorities: { title: 10 },
                                           filters: { language: ->(_document) { I18n.locale.to_s } }
end
