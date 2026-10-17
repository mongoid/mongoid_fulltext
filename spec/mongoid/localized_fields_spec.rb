require 'spec_helper'

describe 'Localized fields' do
  around do |example|
    locales = I18n.available_locales
    begin
      I18n.available_locales = %i[en cs]
      I18n.with_locale(:en) { example.run }
    ensure
      I18n.available_locales = locales
    end
  end

  let(:artwork) { LocalizedArtwork.create!(title_translations: { 'en' => 'Flowers', 'cs' => 'Kvetiny' }, artist: 'Picasso') }

  it 'searches the current locale only' do
    artwork
    expect(LocalizedArtwork.fulltext_search('flowers')).to eq([artwork])
    expect(LocalizedArtwork.fulltext_search('kvetiny')).to eq([])
    I18n.with_locale(:cs) do
      expect(LocalizedArtwork.fulltext_search('kvetiny')).to eq([artwork])
      expect(LocalizedArtwork.fulltext_search('flowers')).to eq([])
    end
  end

  it 'indexes scalar fields and computed methods in every locale' do
    artwork
    %i[en cs].each do |locale|
      I18n.with_locale(locale) { expect(LocalizedArtwork.fulltext_search('picasso')).to eq([artwork]) }
    end
    expect(LocalizedArtwork.fulltext_search('english')).to eq([artwork])
    I18n.with_locale(:cs) { expect(LocalizedArtwork.fulltext_search('cesky')).to eq([artwork]) }
  end

  it 'evaluates filters in the locale of the index' do
    artwork
    expect(LocalizedArtwork.fulltext_search('flowers', language: 'en')).to eq([artwork])
    I18n.with_locale(:cs) { expect(LocalizedArtwork.fulltext_search('kvetiny', language: 'cs')).to eq([artwork]) }
  end

  it 'replaces all translations without changing the caller locale' do
    artwork
    I18n.with_locale(:cs) do
      artwork.title_translations = { 'en' => 'Painting', 'cs' => 'Obraz' }
      artwork.save!
      expect(I18n.locale).to eq(:cs)
      expect(LocalizedArtwork.fulltext_search('kvetiny')).to eq([])
      expect(LocalizedArtwork.fulltext_search('obraz')).to eq([artwork])
    end
    expect(LocalizedArtwork.fulltext_search('flowers')).to eq([])
    expect(LocalizedArtwork.fulltext_search('painting')).to eq([artwork])
  end

  it 'continues after an empty translation in the first locale' do
    document = OnlyLocalizedArtwork.create!(title_translations: { 'en' => '', 'cs' => 'Obraz' })
    I18n.with_locale(:cs) { expect(OnlyLocalizedArtwork.fulltext_search('obraz')).to eq([document]) }
  end

  it 'removes records for a translation that becomes empty' do
    document = OnlyLocalizedArtwork.create!(title_translations: { 'en' => 'Flowers', 'cs' => 'Obraz' })
    document.title_translations = { 'en' => 'Flowers', 'cs' => '' }
    document.save!
    expect(OnlyLocalizedArtwork.fulltext_search('flowers')).to eq([document])
    I18n.with_locale(:cs) { expect(OnlyLocalizedArtwork.fulltext_search('obraz')).to eq([]) }
  end

  it 'evaluates update_if independently in each locale' do
    config = OnlyLocalizedArtwork.mongoid_fulltext_config.values.first
    begin
      config[:update_if] = ->(_document) { I18n.locale == :cs }
      document = OnlyLocalizedArtwork.create!(title_translations: { 'en' => 'Flowers', 'cs' => 'Obraz' })
      expect(OnlyLocalizedArtwork.fulltext_search('flowers')).to eq([])
      I18n.with_locale(:cs) { expect(OnlyLocalizedArtwork.fulltext_search('obraz')).to eq([document]) }
    ensure
      config.delete(:update_if)
    end
  end

  it 'removes all locale indexes for a document' do
    artwork.destroy
    expect(LocalizedArtwork.fulltext_search('flowers')).to eq([])
    I18n.with_locale(:cs) { expect(LocalizedArtwork.fulltext_search('kvetiny')).to eq([]) }
  end

  it 'removes and rebuilds all locales through the class API' do
    artwork
    LocalizedArtwork.remove_from_ngram_index
    expect(LocalizedArtwork.fulltext_search('flowers')).to eq([])
    I18n.with_locale(:cs) { expect(LocalizedArtwork.fulltext_search('kvetiny')).to eq([]) }
    LocalizedArtwork.update_ngram_index
    expect(LocalizedArtwork.fulltext_search('flowers')).to eq([artwork])
    I18n.with_locale(:cs) { expect(LocalizedArtwork.fulltext_search('kvetiny')).to eq([artwork]) }
  end

  it 'stores locales together in the original index collection' do
    artwork
    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    records = LocalizedArtwork.collection.database[name].find.to_a
    expect(records.map { |record| record['locale'] }.uniq.sort).to eq(%w[cs en])
    expect(records.map { |record| record['document_id'] }.uniq).to eq([artwork.id])
    names = []
    LocalizedArtwork.each_fulltext_index { |index_name, _config| names << index_name }
    expect(names).to eq([name, name])
  end

  it 'keeps the same collection when available locales change' do
    I18n.available_locales = [:en]
    artwork
    I18n.available_locales = %i[en cs]
    expect(LocalizedArtwork.fulltext_search('flowers')).to eq([artwork])
  end

  it 'leaves nonlocalized index records unchanged' do
    artwork = PartlyLocalizedArtwork.create!(artist: 'Picasso')
    expect(PartlyLocalizedArtwork.fulltext_search('picasso')).to eq([artwork])
    collections = []
    PartlyLocalizedArtwork.each_fulltext_index { |name, _config| collections << name }
    expect(collections).to eq(['mongoid_fulltext.untranslated'])
    records = PartlyLocalizedArtwork.collection.database[collections.first].find.to_a
    expect(records).not_to be_empty
    expect(records.any? { |record| record.key?('locale') }).to eq(false)
  end

  it 'restores the caller locale when a field reader raises' do
    document = LocalizedArtwork.new
    allow(document).to receive(:description).and_raise('reader failure')
    I18n.with_locale(:cs) do
      expect { document.update_ngram_index }.to raise_error(RuntimeError, 'reader failure')
      expect(I18n.locale).to eq(:cs)
    end
  end

  it 'creates a locale-prefixed compound index in the original collection' do
    LocalizedArtwork.create_indexes
    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    indexes = []
    LocalizedArtwork.collection.database[name].indexes.each { |index| indexes << index }
    if Mongoid::Compatibility::Version.mongoid5_or_newer?
      expect(indexes.map { |index| index['name'] }).to include('fts_index', 'document_id_1')
      keys = indexes.find { |index| index['name'] == 'fts_index' }['key']
      expect(keys.to_a).to eq([['locale', 1], ['ngram', 1], ['score', -1], ['filter_values.language', 1]])
    end
    expect(I18n.locale).to eq(:en)
  end

  it 'removes records for every locale even after a locale is no longer configured' do
    artwork
    I18n.available_locales = [:en]
    artwork.remove_from_ngram_index
    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    expect(LocalizedArtwork.collection.database[name].find.count).to eq(0)
  end

  it 'removes unconfigured locales through the class API' do
    artwork
    I18n.available_locales = [:en]
    LocalizedArtwork.remove_from_ngram_index
    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    expect(LocalizedArtwork.collection.database[name].find.count).to eq(0)
  end

  it 'destroys records for locales that are no longer configured' do
    artwork
    I18n.available_locales = [:en]
    artwork.destroy
    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    expect(LocalizedArtwork.collection.database[name].find.count).to eq(0)
  end

  it 'upgrades an existing search index to include locale' do
    next unless Mongoid::Compatibility::Version.mongoid5_or_newer?

    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    coll = LocalizedArtwork.collection.database[name]
    coll.indexes.drop_all
    coll.indexes.create_one({ 'ngram' => 1, 'score' => -1 }, name: 'fts_index')
    LocalizedArtwork.create_indexes
    keys = coll.indexes.find { |index| index['name'] == 'fts_index' }['key']
    expect(keys.keys.first).to eq('locale')
  end

  it 'keeps scores isolated when the same term exists in both locales' do
    artwork
    en_score = LocalizedArtwork.fulltext_search('picasso', return_scores: true).first.last
    cs_score = I18n.with_locale(:cs) { LocalizedArtwork.fulltext_search('picasso', return_scores: true).first.last }
    config = LocalizedArtwork.mongoid_fulltext_config.values.first
    name = LocalizedArtwork.mongoid_fulltext_config.keys.first
    coll = LocalizedArtwork.collection.database[name]
    %w[en cs].zip([en_score, cs_score]).each do |locale, score|
      query_ngrams = LocalizedArtwork.all_ngrams('picasso', config)
      expected = coll.find('locale' => locale).inject(0.0) do |sum, record|
        sum + record['score'] * (query_ngrams[record['ngram']] || 0)
      end
      expect(score).to be_within(0.00001).of(expected)
    end
  end
end
