class FilteredArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :full_name
  fulltext_search_in :full_name, :index_name => 'mongoid_fulltext.artworks_and_artists',
                     :filters => { :is_foobar => lambda { |x| x.full_name == 'foobar' },
                                   :is_artist => lambda { |x| true },
                                   :is_artwork => lambda { |x| false }
                                  }
end
