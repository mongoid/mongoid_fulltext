require 'spec_helper'

describe 'Bulk ngram indexing' do
  let(:artwork) { BasicArtwork.new(title: 'A long title with many searchable ngrams') }
  let(:index_name) { BasicArtwork.mongoid_fulltext_config.keys.first }
  let(:config) { BasicArtwork.mongoid_fulltext_config[index_name] }
  let(:collection) { artwork.collection }
  let(:database) { collection.database }
  let(:index) { database[index_name] }

  before do
    allow(artwork).to receive(:collection).and_return(collection)
    allow(collection).to receive(:database).and_return(database)
    allow(database).to receive(:[]).and_call_original
    allow(database).to receive(:[]).with(index_name.to_sym).and_return(index)
  end

  it 'inserts all ngrams with one driver call and preserves their scores' do
    documents = BasicArtwork.all_ngrams(artwork.title, config, false).map do |ngram, score|
      { 'ngram' => ngram, 'document_id' => artwork.id, 'score' => score, 'class' => 'BasicArtwork' }
    end
    expect(documents.length).to be > 10
    method = Mongoid::Compatibility::Version.mongoid5_or_newer? ? :insert_many : :insert
    expect(index).to receive(method).with(documents).once.and_call_original
    artwork.save!
    expect(BasicArtwork.fulltext_search(artwork.title)).to eq([artwork])
  end

  it 'does not call insert for an empty ngram set' do
    artwork.title = ''
    expect(index).not_to receive(:insert_many)
    expect(index).not_to receive(:insert)
    artwork.update_ngram_index
    expect(index.find.count).to eq(0)
  end

  it 'replaces previous records rather than accumulating duplicates' do
    artwork.save!
    artwork.update_attributes!(title: 'Replacement')
    expect(BasicArtwork.fulltext_search('searchable')).to eq([])
    expect(BasicArtwork.fulltext_search('replacement')).to eq([artwork])
    expect(index.find.count).to eq(BasicArtwork.all_ngrams('Replacement', config, false).length)
  end

  it 'continues indexing other fields when an earlier index is empty' do
    artwork = MultiExternalArtwork.create!(title: '', year: '1970', artist: 'Picasso')
    expect(MultiExternalArtwork.fulltext_search('1970', index: 'mongoid_fulltext.years')).to eq([artwork])
    expect(MultiExternalArtwork.fulltext_search('Picasso', index: 'mongoid_fulltext.all')).to eq([artwork])
  end

  it 'retains filter values for all inserted ngrams' do
    artwork = FilteredArtwork.create!(title: 'Flowers')
    expect(FilteredArtwork.fulltext_search('flowers', is_artwork: true)).to eq([artwork])
    expect(FilteredArtwork.fulltext_search('flowers', is_artwork: false)).to eq([])
  end
end
