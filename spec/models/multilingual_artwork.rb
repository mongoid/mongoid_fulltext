class MultilingualArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  fulltext_search_in :title, alphabet: /[\p{L}\p{M}\p{N}]/, ngram_width: 2, remove_accents: false
end
