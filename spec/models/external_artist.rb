class ExternalArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :full_name
  fulltext_search_in :full_name, index_name: 'mongoid_fulltext.artworks_and_artists'

  def to_s
    full_name
  end
end
