require 'spec_helper'

describe 'Search with highlights' do
  it 'returns ranked documents, scores and complete highlighted fields without changing the index' do
    first = TaggedArtwork.create!(title: 'Ghost story', tags: [nil, 'ghost', 'painting'])
    TaggedArtwork.create!(title: 'Other & painting', tags: ['ghost'])
    index = TaggedArtwork.mongoid_fulltext_config.keys.first
    collection = first.collection.database[index]
    before = collection.find.to_a
    expected = TaggedArtwork.fulltext_search('ghost', return_scores: true)
    options = { fields: %i[title tags] }
    results = TaggedArtwork.fulltext_search_with_highlights('ghost', options)

    expect(results.map { |result| [result.document, result.score] }).to eq(expected)
    expect(results.find { |result| result.document == first }.highlights)
      .to eq(title: '<b>Ghost</b> story', tags: [nil, '<b>ghost</b>', 'painting'])
    expect(results.find { |result| result.document.title == 'Other & painting' }.highlights[:title]).to eq('Other &amp; painting')
    expect(options).to eq(fields: %i[title tags])
    expect(first.title).to eq('Ghost story')
    expect(collection.find.to_a).to eq(before)
  end

  it 'accepts a renderer and restricts display fields' do
    TaggedArtwork.create!(title: 'Ghost story', tags: ['ghost'])
    result = TaggedArtwork.fulltext_search_with_highlights('ghost', fields: ['title']) { |match| "<mark>#{match}</mark>" }.first
    expect(result.highlights).to eq(title: '<mark>Ghost</mark> story')
  end

  it 'preserves search limits and criteria' do
    selected = BasicArtwork.create!(title: 'ghost selected')
    BasicArtwork.create!(title: 'ghost other')
    results = BasicArtwork.where(id: selected.id).fulltext_search_with_highlights('ghost', max_results: 1)
    expect(results.map(&:document)).to eq([selected])
    expect(BasicArtwork.fulltext_search_with_highlights('unmatched')).to eq([])
  end

  it 'uses the current translation and computed readers' do
    original_locales = I18n.available_locales
    begin
      I18n.available_locales = %i[en cs]
      artwork = LocalizedArtwork.create!(title_translations: { 'en' => 'Flowers', 'cs' => 'Kvetiny' })
      I18n.with_locale(:cs) do
        result = LocalizedArtwork.fulltext_search_with_highlights('kvetiny').first
        expect(result.document).to eq(artwork)
        expect(result.highlights[:title]).to eq('<b>Kvetiny</b>')
        expect(artwork.fulltext_highlights('cesky')[:description]).to eq('<b>Cesky</b>')
        expect(I18n.locale).to eq(:cs)
      end
    ensure
      I18n.available_locales = original_locales
    end
  end

  it 'requires an index when ambiguous and rejects unknown indexes or fields' do
    expect { MultiExternalArtwork.fulltext_search_with_highlights('ghost') }.to raise_error(Mongoid::FullTextSearch::UnspecifiedIndexError)
    expect { BasicArtwork.fulltext_search_with_highlights('ghost', index: 'missing') }.to raise_error(KeyError)
    expect { BasicArtwork.fulltext_search_with_highlights('ghost', fields: [:missing]) }.to raise_error(ArgumentError)
  end

  it 'uses the selected index' do
    artwork = MultiExternalArtwork.create!(title: 'ghost', artist: 'ghost', year: 'ghost')
    result = MultiExternalArtwork.fulltext_search_with_highlights('ghost', index: 'mongoid_fulltext.titles').first
    expect(result.document).to eq(artwork)
    expect(result.highlights).to eq(title: '<b>ghost</b>')
  end
end
