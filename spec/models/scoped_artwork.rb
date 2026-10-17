class ScopedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String
  field :value, type: Integer
  fulltext_search_in :title
end

class InheritedArtwork < ScopedArtwork
end

class FurtherInheritedArtwork < InheritedArtwork
end
