require 'spec_helper'

describe 'Class-level indexing timeout options' do
  it 'rebuilds all records with cursor timeouts disabled' do
    first = DelayedArtwork.create!(title: 'Flowers 1')
    second = DelayedArtwork.create!(title: 'Flowers 2')
    expect(DelayedArtwork.fulltext_search('flower')).to eq([])
    DelayedArtwork.update_ngram_index(timeout: false)
    expect(DelayedArtwork.fulltext_search('flower')).to match_array([first, second])
  end

  it 'applies the no_timeout option to the class criteria' do
    items = DelayedArtwork.all
    expect(DelayedArtwork).to receive(:all).and_return(items)
    expect(items).to receive(:no_timeout).and_call_original
    DelayedArtwork.update_ngram_index(timeout: false)
  end
end
