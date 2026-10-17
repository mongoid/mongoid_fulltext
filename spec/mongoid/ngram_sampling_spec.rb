require 'spec_helper'

describe 'Bounded ngram sampling' do
  let(:config) do
    BasicArtwork.mongoid_fulltext_config.values.first.merge(
      max_ngrams_to_search: 3, index_full_words: false, index_short_prefixes: false
    )
  end

  it 'selects the documented evenly spaced sample including the last ngram' do
    expect(BasicArtwork.all_ngrams('abcdefghijk', config).keys).to eq(%w[abc efg ijk])
    expect(BasicArtwork.all_ngrams('abcdefghij', config).keys).to eq(%w[abc efg hij])
  end

  it 'never exceeds the configured number of sliding-window ngrams' do
    (1..12).each do |limit|
      (0..26).each do |length|
        text = 'abcdefghijklmnopqrstuvwxyz'[0, length]
        ngrams = BasicArtwork.all_ngrams(text, config.merge(max_ngrams_to_search: limit))
        expected_count = [[length - config[:ngram_width] + 1, 0].max, limit].min
        expect(ngrams.length).to eq(expected_count)
        next unless expected_count > 1

        expect(ngrams.keys.first).to eq(text[0, 3])
        expect(ngrams.keys.last).to eq(text[-3, 3])
      end
    end
  end

  it 'selects the prefix when only one ngram is requested' do
    expect(BasicArtwork.all_ngrams('abcdefghijk', config.merge(max_ngrams_to_search: 1)).keys).to eq(['abc'])
  end

  it 'still indexes every sliding window when the bound is disabled' do
    expect(BasicArtwork.all_ngrams('abcdefghijk', config, false).keys).to eq(%w[abc bcd cde def efg fgh ghi hij ijk])
  end

  it 'preserves full-word and short-prefix bonuses in addition to sampled ngrams' do
    options = config.merge(index_full_words: true, index_short_prefixes: true)
    expect(BasicArtwork.all_ngrams('abcdefghijk', options).keys).to eq(%w[abc efg ijk ab abcdefghijk])
  end

  it 'rejects a nonpositive or noninteger search bound' do
    [0, -1, 1.5, nil].each do |limit|
      expect do
        BasicArtwork.fulltext_search_in :title, max_ngrams_to_search: limit
      end.to raise_error(ArgumentError, ':max_ngrams_to_search must be a positive integer')
    end
  end
end
