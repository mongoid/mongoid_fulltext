class AccentlessArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title, remove_accents: false
end
