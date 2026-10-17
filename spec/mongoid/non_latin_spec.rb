require 'spec_helper'

describe 'Non-Latin alphabets' do
  it 'searches Chinese characters included in the configured alphabet' do
    artwork = ChineseArtwork.create!(title: "\u5367\u864e\u85cf\u9f99")
    expect(ChineseArtwork.fulltext_search("\u85cf\u9f99")).to eq([artwork])
    expect(ChineseArtwork.fulltext_search("\u5367\u864e")).to eq([artwork])
  end

  it 'does not index characters outside the configured alphabet' do
    artwork = BasicArtwork.create!(title: "\u5367\u864e\u85cf\u9f99")
    expect(BasicArtwork.fulltext_search(artwork.title)).to eq([])
  end

  it 'supports Han characters outside the example title without enumerating them' do
    artwork = ChineseArtwork.create!(title: "\u4e2d\u6587\u641c\u7d22")
    expect(ChineseArtwork.fulltext_search("\u641c\u7d22")).to eq([artwork])
    expect(ChineseArtwork.fulltext_search("\u4e2d\u6587")).to eq([artwork])
    expect(ChineseArtwork.fulltext_search('search')).to eq([])
  end

  it 'supports Unicode letters, combining marks, and numbers across scripts' do
    artwork = MultilingualArtwork.create!(title: "Flowers \u0428\u0418\u0428\u041a\u0418\u041d \u4e2d\u6587 123")
    %w[flowers шишкин 中文 123].each do |query|
      expect(MultilingualArtwork.fulltext_search(query)).to eq([artwork])
    end
    config = MultilingualArtwork.mongoid_fulltext_config.values.first.merge(index_full_words: false)
    expect(MultilingualArtwork.all_ngrams("e\u0301", config).keys).to eq(["e\u0301"])
  end

  it 'retains word separators independently of the regular expression' do
    config = ChineseArtwork.mongoid_fulltext_config.values.first.merge(index_full_words: false)
    expect(ChineseArtwork.all_ngrams("\u4e2d-\u6587", config).keys).to eq(["\u4e2d-", "-\u6587"])
    expect(ChineseArtwork.all_ngrams("\u4e2d!\u6587", config).keys).to eq(["\u4e2d\u6587"])
  end

  it 'preserves explicit string allowlists' do
    expect(RussianArtwork.mongoid_fulltext_config.values.first[:alphabet]).to be_a(Hash)
    artwork = RussianArtwork.create!(title: "\u0428\u0438\u0448\u043a\u0438\u043d")
    expect(RussianArtwork.fulltext_search("\u0448\u0438\u0448\u043a\u0438\u043d")).to eq([artwork])
  end

  it 'rejects unsupported alphabet types at declaration time' do
    [nil, [], 123].each do |alphabet|
      expect do
        ChineseArtwork.fulltext_search_in :title, alphabet: alphabet
      end.to raise_error(ArgumentError, ':alphabet must be a String or Regexp')
    end
  end
end
