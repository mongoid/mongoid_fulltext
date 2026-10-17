class LocalizedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String, localize: true
  field :artist, type: String
  fulltext_search_in :title, :artist, :description, filters: { language: ->(_document) { I18n.locale.to_s } }

  def description
    I18n.locale == :cs ? 'Cesky' : 'English'
  end
end

class PartlyLocalizedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String, localize: true
  field :artist, type: String
  fulltext_search_in :artist, index_name: 'mongoid_fulltext.untranslated'
end

class OnlyLocalizedArtwork
  include Mongoid::Document
  include Mongoid::FullTextSearch

  field :title, type: String, localize: true
  fulltext_search_in :title
end
