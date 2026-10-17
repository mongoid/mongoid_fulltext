require 'spec_helper'

describe 'Scoped full-text searches' do
  it 'combines criteria with locale filtering' do
    I18n.with_locale(:en) do
      included = LocalizedArtwork.create!(title_translations: { 'en' => 'Flowers' }, artist: 'Picasso')
      LocalizedArtwork.create!(title_translations: { 'en' => 'Flowers' }, artist: 'Monet')
      expect(LocalizedArtwork.where(artist: 'Picasso').fulltext_search('flowers')).to eq([included])
    end
  end

  it 'applies criteria without raising for excluded documents' do
    excluded = ScopedArtwork.create!(title: 'My Doc', value: 0)
    included = ScopedArtwork.create!(title: 'My Doc 2', value: 10)
    expect(ScopedArtwork.where(value: 10).fulltext_search('doc')).to eq([included])
    expect(ScopedArtwork.fulltext_search('doc')).to include(excluded, included)
  end

  it 'fills the result limit after filtering higher-ranked documents' do
    ScopedArtwork.create!(title: 'Flowers', value: 0)
    included = ScopedArtwork.create!(title: 'Flowers in a vase', value: 10)
    expect(ScopedArtwork.where(value: 10).fulltext_search('flowers', max_results: 1)).to eq([included])
  end

  it 'preserves scores and relevance order in a scoped search' do
    first = ScopedArtwork.create!(title: 'Flowers', value: 10)
    second = ScopedArtwork.create!(title: 'Flowers in a vase', value: 10)
    results = ScopedArtwork.where(value: 10).fulltext_search('flowers', return_scores: true)
    expect(results.map(&:first)).to eq([first, second])
    expect(results.first.last).to be > results.last.last
  end

  it 'preserves the existing zero-limit behavior for unscoped searches' do
    first = ScopedArtwork.create!(title: 'Flowers')
    second = ScopedArtwork.create!(title: 'Flowers in a vase')
    expect(ScopedArtwork.fulltext_search('flowers', max_results: 0)).to eq([first, second])
  end

  it 'searches descendants without returning parent or sibling documents' do
    parent = ScopedArtwork.create!(title: 'My Doc')
    child = InheritedArtwork.create!(title: 'My Inherited Doc')
    grandchild = FurtherInheritedArtwork.create!(title: 'My Further Inherited Doc')
    expect(ScopedArtwork.fulltext_search('doc')).to match_array([parent, child, grandchild])
    expect(InheritedArtwork.fulltext_search('doc')).to match_array([child, grandchild])
    expect(FurtherInheritedArtwork.fulltext_search('doc')).to eq([grandchild])
  end

  it 'does not raise for dangling index references even when Mongoid raises on find' do
    artwork = ScopedArtwork.create!(title: 'Flowers')
    artwork.delete
    previous = Mongoid.raise_not_found_error
    begin
      Mongoid.raise_not_found_error = true
      expect(ScopedArtwork.fulltext_search('flowers')).to eq([])
      expect(ScopedArtwork.fulltext_search('flowers', return_scores: true)).to eq([])
    ensure
      Mongoid.raise_not_found_error = previous
    end
  end

  it 'keeps unscoped shared-index searches across unrelated models' do
    artist = ExternalArtist.create!(full_name: 'Picasso')
    artwork = ExternalArtwork.create!(title: 'Picasso')
    expect(ExternalArtwork.fulltext_search('picasso')).to match_array([artist, artwork])
    expect(ExternalArtwork.where(title: 'Picasso').fulltext_search('picasso')).to eq([artwork])
  end
end
