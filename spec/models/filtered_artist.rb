class FilteredArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :full_name
  fulltext_search_in :full_name, index_name: 'mongoid_fulltext.artworks_and_artists',
                                 filters: { is_foobar: ->(x) { x.full_name == 'foobar' },
                                            is_artist: ->(_x) { true },
                                            is_artwork: ->(_x) { false }
                                  }
end
