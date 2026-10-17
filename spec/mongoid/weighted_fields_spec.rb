require 'spec_helper'

describe 'Weighted fields' do
  def records(artwork, index)
    Hash[artwork.collection.database[index].find('document_id' => artwork.id).map do |record|
      [record['ngram'], record['score']]
    end]
  end

  it 'ranks identical title matches above description and default-weight tag matches' do
    title = WeightedArtwork.create!(title: 'ghost')
    description = WeightedArtwork.create!(description: 'ghost')
    tags = WeightedArtwork.create!(tags: ['ghost'])
    %w[weighted_max weighted_sum].each do |index|
      results = WeightedArtwork.fulltext_search('ghost', index: index, return_scores: true)
      expect(results.map(&:first)).to eq([title, description, tags])
      expect(results[0][1]).to be_within(0.000001).of(results[2][1] * 10)
      expect(results[1][1]).to be_within(0.000001).of(results[2][1] * 5)
    end
  end

  it 'takes the maximum within array fields and combines fields with the configured mode' do
    artwork = WeightedArtwork.create!(title: 'ghost', description: 'ghost', tags: %w[ghost ghost])
    config = WeightedArtwork.mongoid_fulltext_config['weighted_max']
    base = WeightedArtwork.all_ngrams('ghost', config, false)
    expect(records(artwork, 'weighted_max')).to eq(Hash[base.map { |term, score| [term, score * 10] }])
    expect(records(artwork, 'weighted_sum')).to eq(Hash[base.map { |term, score| [term, score * 16] }])
  end

  it 'retains the strongest array-element contribution regardless of element order' do
    artwork = WeightedArtwork.create!(tags: ['ghost', 'ghost story', nil, ''])
    original = records(artwork, 'weighted_sum')
    artwork.update_attributes!(tags: ['ghost story', '', 'ghost', nil, 'ghost'])
    expect(records(artwork, 'weighted_sum')).to eq(original)
  end

  it 'replaces scores on save and removes terms when fields are cleared or destroyed' do
    artwork = WeightedArtwork.create!(title: 'ghost', tags: ['ghost'])
    initial = records(artwork, 'weighted_max')
    artwork.update_attributes!(title: nil)
    expect(records(artwork, 'weighted_max')).to eq(Hash[initial.map { |term, score| [term, score / 10] }])
    artwork.update_attributes!(tags: [])
    expect(records(artwork, 'weighted_max')).to eq({})
    artwork.update_attributes!(description: 'painting')
    artwork.destroy
    expect(records(artwork, 'weighted_sum')).to eq({})
  end

  it 'does not weight query ngrams' do
    config = WeightedArtwork.mongoid_fulltext_config['weighted_max']
    expect(WeightedArtwork.all_ngrams('ghost', config)).to eq(
      WeightedArtwork.all_ngrams('ghost', config.merge(priorities: {}, score_aggregation: :sum))
    )
  end

  it 'weights computed readers and supports class-level rebuilding' do
    artwork = WeightedComputedArtwork.create!(title: 'ghost')
    config = WeightedComputedArtwork.mongoid_fulltext_config.values.first
    index = WeightedComputedArtwork.mongoid_fulltext_config.keys.first
    expected = Hash[WeightedComputedArtwork.all_ngrams('ghost', config, false).map { |term, score| [term, score + score * 2.5] }]
    expect(records(artwork, index)).to eq(expected)
    WeightedComputedArtwork.remove_from_ngram_index
    WeightedComputedArtwork.update_ngram_index(timeout: false)
    expect(records(artwork, index)).to eq(expected)
  end

  it 'preserves exact legacy last-field scores when neither option is specified' do
    artwork = TaggedArtwork.create!(title: 'ghost', tags: ['ghost story'])
    config = TaggedArtwork.mongoid_fulltext_config.values.first
    expected = TaggedArtwork.all_ngrams('ghost', config, false).merge(
      TaggedArtwork.all_ngrams('ghost story', config, false)
    )
    expect(records(artwork, TaggedArtwork.mongoid_fulltext_config.keys.first)).to eq(expected)
  end

  it 'rejects invalid configuration before registering a new index' do
    before = BasicArtwork.mongoid_fulltext_config.dup
    expect do
      BasicArtwork.fulltext_search_in :title, priorities: { missing: 2 }
    end.to raise_error(ArgumentError, ':priorities keys must name indexed fields')
    expect(BasicArtwork.mongoid_fulltext_config).to eq(before)
  end

  it 'keeps localized weighted scores and filters isolated' do
    original_locales = I18n.available_locales
    begin
      I18n.available_locales = %i[en cs]
      artwork = WeightedLocalizedArtwork.new(description: 'ghost')
      artwork.title_translations = { 'en' => 'ghost', 'cs' => 'painting' }
      artwork.save!
      english = I18n.with_locale(:en) do
        WeightedLocalizedArtwork.fulltext_search('ghost', return_scores: true, language: 'en').first[1]
      end
      czech = I18n.with_locale(:cs) do
        WeightedLocalizedArtwork.fulltext_search('ghost', return_scores: true, language: 'cs').first[1]
      end
      expect(english).to be_within(0.000001).of(czech * 10)
    ensure
      I18n.available_locales = original_locales
    end
  end
end
