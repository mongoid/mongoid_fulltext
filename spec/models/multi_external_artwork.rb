class MultiExternalArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title
  field :year
  field :artist
  fulltext_search_in :title, :external_index => 'fulltext_titles'
  fulltext_search_in :year, :external_index => 'fulltext_years'
  fulltext_search_in :title, :year, :artist, :external_index => 'fulltext_all'
end
