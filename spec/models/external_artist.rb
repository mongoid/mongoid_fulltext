class ExternalArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :full_name
  fulltext_search_in :full_name, :external_index => 'artworks_and_artists'
end
