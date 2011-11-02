class StopwordsArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  fulltext_search_in :title, 
  :index_full_words => true,
  :stop_words => { 'and' => true }

end
