class BasicArtist
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title

end
