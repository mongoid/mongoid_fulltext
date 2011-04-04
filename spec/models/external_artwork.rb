class ExternalArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title
  fulltext_search_in :title, :external_index => 'artworks_and_artists'
end
