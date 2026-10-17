require 'spec_helper'

describe 'Full-text candidate limits' do
  it 'bounds initial candidates and continues with limited candidates for later ngrams' do
    config = BasicArtwork.mongoid_fulltext_config.values.first
    original = config[:max_candidate_set_size]
    begin
      config[:max_candidate_set_size] = 1
      artworks = 2.times.map { BasicArtwork.create!(title: 'alphabet beta') }

      results = BasicArtwork.fulltext_search('alphabet beta', max_results: 1, return_scores: true)
      expect(results.length).to eq(1)
      expect(artworks).to include(results.first.first)
      expect(results.first.last).to be > 0
    ensure
      config[:max_candidate_set_size] = original
    end
  end
end
