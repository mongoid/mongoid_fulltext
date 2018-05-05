class MyDoc
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title
  field :value, type: Integer

  fulltext_search_in :title
end
