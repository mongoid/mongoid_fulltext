require 'rspec'
require 'mongoid/full_text_search/ngrams'

describe Mongoid::FullTextSearch::Ngrams do
  let(:config) do
    {
      alphabet: /[\p{L}\p{M}\p{N}]/,
      word_separators: { ' ' => ' ', '-' => '-' },
      ngram_width: 3,
      max_ngrams_to_search: 3,
      remove_accents: true,
      apply_prefix_scoring_to_all_words: true,
      index_full_words: false,
      index_short_prefixes: false,
      stop_words: { 'the' => true }
    }
  end

  it 'handles nil and strings shorter than a window' do
    [nil, '', 'ab'].each { |text| expect(described_class.calculate(text, config)).to eq({}) }
  end

  it 'samples endpoints and preserves exact prefix and interior scores' do
    expect(described_class.calculate('abcdefghijk', config)).to eq(
      'abc' => Math.sqrt(1 + 1.0 / 11),
      'efg' => Math.sqrt(2.0 / 11),
      'ijk' => Math.sqrt(2.0 / 11)
    )
  end

  it 'uses every window for unbounded indexing' do
    expect(described_class.calculate('abcdef', config, false).keys).to eq(%w[abc bcd cde def])
  end

  it 'keeps the maximum score of repeated windows rather than adding them' do
    expect(described_class.calculate('aaaa', config, false)).to eq('aaa' => Math.sqrt(1 + 1.0 / 4))
  end

  it 'adds window and full-word scores for the same term only once each' do
    options = config.merge(index_full_words: true)
    expect(described_class.calculate('cat cat', options, false)).to eq(
      'cat' => Math.sqrt(1 + 1.0 / 7) + (1 + 1.0 / 7),
      'at ' => Math.sqrt(2.0 / 7),
      't c' => Math.sqrt(2.0 / 7),
      ' ca' => Math.sqrt(2.0 / 7)
    )
  end

  it 'combines short-prefix and full-word bonuses without duplicate prefixes' do
    options = config.merge(ngram_width: 4, index_short_prefixes: true, index_full_words: true)
    ngrams = described_class.calculate('cat cats', options, false)
    expect(ngrams['cat']).to eq(2 * (1 + 1.0 / 8))
  end

  it 'suppresses stop-word bonuses unless the word is the whole input' do
    options = config.merge(index_full_words: true, index_short_prefixes: true)
    expect(described_class.calculate('the cat', options)['th']).to be_nil
    expect(described_class.calculate('the cat', options)['the']).to eq(Math.sqrt(1 + 1.0 / 7))
    expect(described_class.calculate('the', options)['th']).to eq(1 + 1.0 / 3)
  end

  it 'normalizes Unicode and preserves configured separators' do
    expect(described_class.calculate("CAF\u00c9-\u4e2d\u6587", config).keys).to eq(['caf', "e\u0301-", "-\u4e2d\u6587"])
  end

  it 'does not mutate configuration or source text' do
    text = 'Cat'.freeze
    original = Marshal.dump(config)
    described_class.calculate(text, config.freeze)
    expect(Marshal.dump(config)).to eq(original)
    expect(text).to eq('Cat')
  end
end
