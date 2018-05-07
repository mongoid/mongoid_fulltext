class MyLocalizedDoc
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, localize: true

  fulltext_search_in :title
end
