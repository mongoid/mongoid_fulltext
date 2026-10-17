require 'rspec'
require_relative '../../lib/mongoid/full_text_search/field_scores'

describe Mongoid::FullTextSearch::FieldScores do
  it 'leaves unconfigured indexes on the legacy path' do
    config = {}
    described_class.configure(config, [:title])
    expect(config).to eq({})
  end

  it 'normalizes field names and defaults weighted indexes to maximum aggregation' do
    priorities = { title: 2, 'description' => 0.5 }
    config = { priorities: priorities }
    described_class.configure(config, %i[title description])
    expect(config).to eq(priorities: { 'title' => 2.0, 'description' => 0.5 }, score_aggregation: :max)
    expect(priorities).to eq(title: 2, 'description' => 0.5)
  end

  it 'allows aggregation without explicit weights and supports to_s' do
    config = { score_aggregation: :sum }
    described_class.configure(config, [:to_s])
    expect(config[:priorities]).to eq({})
    described_class.configure({ priorities: { to_s: 3 } }, [:to_s])
  end

  it 'rejects invalid weights' do
    [nil, '2', 0, -1, Float::NAN, Float::INFINITY, Complex(1, 1)].each do |weight|
      expect do
        described_class.configure({ priorities: { title: weight } }, [:title])
      end.to raise_error(ArgumentError, ':priorities values must be positive finite numbers')
    end
  end

  it 'rejects unknown, duplicate, or invalid field names' do
    [{ missing: 2 }, { nil => 2 }, { title: 2, 'title' => 3 }].each do |priorities|
      expect do
        described_class.configure({ priorities: priorities }, [:title])
      end.to raise_error(ArgumentError)
    end
  end

  it 'rejects invalid priority maps and aggregation modes' do
    [nil, [], 1].each do |priorities|
      expect do
        described_class.configure({ priorities: priorities }, [:title])
      end.to raise_error(ArgumentError, ':priorities must be a Hash')
    end
    [nil, :average, 'sum'].each do |mode|
      expect do
        described_class.configure({ score_aggregation: mode }, [:title])
      end.to raise_error(ArgumentError, ':score_aggregation must be :max or :sum')
    end
  end
end
