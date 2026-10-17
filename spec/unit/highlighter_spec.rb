require 'rspec'
require 'mongoid/full_text_search/highlighter'

describe Mongoid::FullTextSearch::Highlighter do
  let(:config) do
    {
      alphabet: Hash[('a'..'z').map { |character| [character, true] }],
      word_separators: { ' ' => true, '-' => true },
      ngram_width: 3, max_ngrams_to_search: 6, remove_accents: true,
      apply_prefix_scoring_to_all_words: true, index_full_words: true,
      index_short_prefixes: false, stop_words: { 'the' => true }
    }
  end

  it 'highlights complete text and escapes source HTML' do
    expect(described_class.highlight('A GHOST & <script>alert(1)</script>', 'ghost', config))
      .to eq('A <b>GHOST</b> &amp; &lt;script&gt;alert(1)&lt;/script&gt;')
  end

  it 'preserves composed and decomposed graphemes' do
    %w[Café Café].each do |text|
      expect(described_class.highlight(text, 'cafe', config)).to eq("<b>#{text}</b>")
    end
  end

  it 'includes discarded punctuation inside a merged match' do
    expect(described_class.highlight('g.h.o.s.t', 'ghost', config)).to eq('<b>g.h.o.s.t</b>')
  end

  it 'supports Unicode alphabets' do
    options = config.merge(alphabet: /[\p{L}\p{M}\p{N}]/)
    expect(described_class.highlight("\u4e2d\u6587 Caf\u00e9", 'cafe', options)).to eq("\u4e2d\u6587 <b>Caf\u00e9</b>")
  end

  it 'highlights all distant matches without truncating text' do
    text = "ghost#{' ' * 200}ghost"
    expect(described_class.highlight(text, 'ghost', config)).to eq("<b>ghost</b>#{' ' * 200}<b>ghost</b>")
  end

  it 'passes escaped merged matches to a custom renderer' do
    matches = []
    html = described_class.highlight('g<h>ost & ghost', 'ghost', config) do |match|
      matches << match
      "<mark>#{match}</mark>"
    end
    expect(matches).to eq(['g&lt;h&gt;ost', 'ghost'])
    expect(html).to eq('<mark>g&lt;h&gt;ost</mark> &amp; <mark>ghost</mark>')
  end

  it 'preserves nil and escapes unmatched or empty-query text without calling the renderer' do
    expect(described_class.highlight(nil, 'ghost', config)).to be_nil
    [nil, '', '!!!', 'ghost'].each do |query|
      expect(described_class.highlight('art & painting', query, config) { raise 'unexpected callback' }).to eq('art &amp; painting')
    end
    expect(described_class.highlight('', 'ghost', config)).to eq('')
  end

  it 'propagates renderer errors' do
    expect do
      described_class.highlight('ghost', 'ghost', config) { raise 'renderer failed' }
    end.to raise_error(RuntimeError, 'renderer failed')
  end

  it 'respects bounded query samples' do
    options = config.merge(max_ngrams_to_search: 2, index_full_words: false)
    expect(described_class.highlight('def', 'abcdefghijk', options)).to eq('def')
    expect(described_class.highlight('abc and ijk', 'abcdefghijk', options)).to eq('<b>abc</b> and <b>ijk</b>')
  end

  it 'respects full-word and short-prefix boundaries' do
    expect(described_class.highlight('bob bobcat', 'bob', config.merge(ngram_width: 6))).to eq('<b>bob</b> bobcat')
    options = config.merge(ngram_width: 4, index_full_words: false, index_short_prefixes: true)
    expect(described_class.highlight('abcat cater', 'cat', options)).to eq('abcat <b>cat</b>er')
  end

  it 'respects stop words while retaining sliding-window matches' do
    expect(described_class.highlight('the cat', 'the', config.merge(ngram_width: 4))).to eq('the cat')
    expect(described_class.highlight('the cat', 'the', config)).to eq('<b>the</b> cat')
  end

  it 'does not mutate inputs' do
    text = 'A ghost'.freeze
    query = 'ghost'.freeze
    original = Marshal.dump(config)
    described_class.highlight(text, query, config.freeze)
    expect(text).to eq('A ghost')
    expect(query).to eq('ghost')
    expect(Marshal.dump(config)).to eq(original)
  end
end
