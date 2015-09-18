class MultiFieldArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :full_name
  field :birth_year
  fulltext_search_in :full_name, :birth_year, index_name: 'mongoid_fulltext.artworks_and_artists'
end
