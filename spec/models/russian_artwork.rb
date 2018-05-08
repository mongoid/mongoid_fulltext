
class RussianArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  Alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789абвгдежзиклмнопрстуфхцчшщъыьэюя'.freeze

  field :title
  fulltext_search_in :title, alphabet: Alphabet
end
