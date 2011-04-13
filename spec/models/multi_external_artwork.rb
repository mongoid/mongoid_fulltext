class MultiExternalArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title
  field :year
  field :artist
  fulltext_search_in :title, :index_name => 'mongoid_fulltext.titles'
  fulltext_search_in :year, :index_name => 'mongoid_fulltext.years'
  fulltext_search_in :title, :year, :artist, :index_name => 'mongoid_fulltext.all'
end
