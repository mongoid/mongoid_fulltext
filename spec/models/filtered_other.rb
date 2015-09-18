# This is some other model that lives in the same index with FilteredArtist and FilteredArtwork,
# to make sure different filters can co-exist in the same index and are indexed properly.
class FilteredOther
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :name
  fulltext_search_in :name, index_name: 'mongoid_fulltext.artworks_and_artists',
                            filters: { is_fuzzy: ->(_x) { true },
                                       is_awesome: ->(_x) { false }
                                  }
end
