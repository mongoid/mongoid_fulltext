class TaggedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  field :tags, type: Array

  fulltext_search_in :title, :tags
end
