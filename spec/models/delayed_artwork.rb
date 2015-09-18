class DelayedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title, reindex_immediately: false
end
