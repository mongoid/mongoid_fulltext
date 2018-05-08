class PartitionedArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :full_name
  field :exhibitions, type: Array, default: []

  fulltext_search_in :full_name,
                     index_name: 'mongoid_fulltext.partitioned_artists',
                     filters: {
                       has_exhibitions: ->(x) { !x.exhibitions.empty? },
                       exhibitions: ->(x) { [x.exhibitions].flatten }
                     }
end
