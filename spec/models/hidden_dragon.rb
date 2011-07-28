# a Mongoid model that doesn't have a fulltext search index, but includes the Mongoid::FullTextSearch module
class HiddenDragon
  include Mongoid::Document
  include Mongoid::FullTextSearch
  
end
