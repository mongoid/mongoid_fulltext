class Artist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title

end
