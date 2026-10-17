require 'rspec'
require 'mongoid/full_text_search/index_definition'

describe Mongoid::FullTextSearch::IndexDefinition do
  it 'builds the nonlocalized search keys without filters' do
    definition = described_class.new(nil, false, [])
    expect(definition.keys).to eq([['ngram', 1], ['score', -1]])
    expect(definition.obsolete_indexes).to eq([])
  end

  it 'sorts filters and prefixes localized keys with locale' do
    definition = described_class.new({ z: true, a: true }, true, [])
    expect(definition.keys).to eq([['locale', 1], ['ngram', 1], ['score', -1], ['filter_values.a', 1], ['filter_values.z', 1]])
  end

  it 'retains shared-model filters and identifies incomplete search indexes' do
    old = { 'name' => 'fts_index', 'key' => { 'ngram' => 1, 'score' => -1, 'filter_values.z' => 1 } }
    unrelated = { 'name' => 'document_id_1', 'key' => { 'document_id' => 1 } }
    definition = described_class.new({ a: true }, true, [unrelated, old])
    expect(definition.keys).to eq([['locale', 1], ['ngram', 1], ['score', -1], ['filter_values.a', 1], ['filter_values.z', 1]])
    expect(definition.obsolete_indexes).to eq([old])
  end

  it 'preserves a complete index that includes other models filters' do
    existing = { 'key' => { 'ngram' => 1, 'score' => -1, 'filter_values.a' => 1, 'filter_values.z' => 1 } }
    definition = described_class.new({ a: true }, false, [existing])
    expect(definition.obsolete_indexes).to eq([])
    expect(definition.keys).to eq(existing['key'].to_a)
  end

  it 'preserves direction-insensitive matching rather than changing index policy' do
    existing = { 'key' => { 'ngram' => -1, 'score' => 1 } }
    expect(described_class.new(nil, false, [existing]).obsolete_indexes).to eq([])
  end

  it 'identifies a search index whose keys are in the wrong order' do
    existing = { 'key' => { 'score' => -1, 'ngram' => 1 } }
    expect(described_class.new(nil, false, [existing]).obsolete_indexes).to eq([existing])
  end

  it 'does not mutate existing definitions or filter configuration' do
    filters = { a: true }.freeze
    existing = [{ 'key' => { 'ngram' => 1, 'filter_values.z' => 1 } }]
    original = Marshal.dump(existing)
    described_class.new(filters, true, existing)
    expect(Marshal.dump(existing)).to eq(original)
  end
end
