class ChineseArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  fulltext_search_in :title, alphabet: /\p{Han}/, ngram_width: 2
end
