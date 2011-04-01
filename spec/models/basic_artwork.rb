class BasicArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title

end
