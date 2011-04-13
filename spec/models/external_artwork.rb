class ExternalArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title
  fulltext_search_in :title, :index_name => 'mongoid_fulltext.artworks_and_artists'
end
