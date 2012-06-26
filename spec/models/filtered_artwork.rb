class FilteredArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch
  field :title, :type => String
  field :colors, :type => Array, :default => []
  fulltext_search_in :title, :index_name => 'mongoid_fulltext.artworks_and_artists',
                     :filters => { :is_foobar => lambda { |x| x.title == 'foobar' },
                                   :is_artwork => lambda { |x| true },
                                   :is_artist => lambda { |x| false },
                                   :colors? => lambda { |x| x.colors }
                                  }
end
