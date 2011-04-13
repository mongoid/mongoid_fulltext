class MultiFieldArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title
  field :year
  fulltext_search_in :title, :year, :index_name => 'mongoid_fulltext.artworks_and_artists'
end
