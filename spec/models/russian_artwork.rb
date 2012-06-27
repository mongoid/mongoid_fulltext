# coding: utf-8
class RussianArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  Alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789абвгдежзиклмнопрстуфхцчшщъыьэюя'

  field :title
  fulltext_search_in :title, :alphabet => Alphabet
end