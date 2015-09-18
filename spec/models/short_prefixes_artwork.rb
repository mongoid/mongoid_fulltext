class ShortPrefixesArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title,
                     ngram_width: 4,
                     index_short_prefixes: true,
                     index_full_words: false
end
