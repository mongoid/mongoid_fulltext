class ExternalArtworkNoFieldsSupplied
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title
  field :year
  field :artist
  fulltext_search_in :index_name => 'mongoid_fulltext.artworks_and_artists'

  def to_s
    '%s (%s %s)' % [title, artist, year] 
  end
end
