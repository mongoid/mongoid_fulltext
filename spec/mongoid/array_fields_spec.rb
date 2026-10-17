require 'spec_helper'

describe 'Array fields' do
  it 'searches each tag as well as scalar fields' do
    artwork = TaggedArtwork.create!(title: 'Painting', tags: %w[ghost accounting])
    %w[painting ghost accounting].each do |query|
      expect(TaggedArtwork.fulltext_search(query)).to eq([artwork])
    end
  end

  it 'does not create ngrams across array element boundaries' do
    artwork = TaggedArtwork.create!(tags: %w[ab cd])
    config = TaggedArtwork.mongoid_fulltext_config.values.first
    coll = artwork.collection.database[TaggedArtwork.mongoid_fulltext_config.keys.first]
    expected = %w[ab cd].inject({}) do |ngrams, tag|
      ngrams.update(TaggedArtwork.all_ngrams(tag, config, false))
    end
    actual = Hash[coll.find.map { |document| [document['ngram'], document['score']] }]
    expect(actual).to eq(expected)
  end

  it 'handles nil, empty, and repeated elements without duplicate records' do
    artwork = TaggedArtwork.create!(tags: [nil, '', 'ghost', 'ghost'])
    expect(TaggedArtwork.fulltext_search('ghost')).to eq([artwork])
    coll = artwork.collection.database[TaggedArtwork.mongoid_fulltext_config.keys.first]
    ngrams = coll.find.map { |document| document['ngram'] }
    expect(ngrams).to eq(ngrams.uniq)
  end

  it 'removes old tags when the array changes or becomes empty' do
    artwork = TaggedArtwork.create!(tags: ['ghost'])
    artwork.update_attributes!(tags: ['accounting'])
    expect(TaggedArtwork.fulltext_search('ghost')).to eq([])
    expect(TaggedArtwork.fulltext_search('accounting')).to eq([artwork])
    artwork.update_attributes!(tags: [])
    expect(TaggedArtwork.fulltext_search('accounting')).to eq([])
  end

  it 'still indexes scalar fields when the array is nil' do
    artwork = TaggedArtwork.create!(title: 'Painting', tags: nil)
    expect(TaggedArtwork.fulltext_search('painting')).to eq([artwork])
  end
end
