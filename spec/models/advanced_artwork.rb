class AdvancedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title, ngram_width: 4, alphabet: 'abcdefg'
end
