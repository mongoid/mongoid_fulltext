# coding: utf-8
require 'spec_helper'

describe Mongoid::FullTextSearch do
  context 'with several config options defined' do
    let!(:abcdef) { AdvancedArtwork.create(title: 'abcdefg hijklmn') }
    let!(:cesar) { AccentlessArtwork.create(title: "C\u00e9sar Galicia") }
    let!(:julio) { AccentlessArtwork.create(title: 'Julio Cesar Morales') }

    it 'should recognize all options' do
      # AdvancedArtwork is defined with an ngram_width of 4 and a different alphabet (abcdefg)
      expect(AdvancedArtwork.fulltext_search('abc')).to eq([])
      expect(AdvancedArtwork.fulltext_search('abcd').first).to eq(abcdef)
      expect(AdvancedArtwork.fulltext_search('defg').first).to eq(abcdef)
      expect(AdvancedArtwork.fulltext_search('hijklmn')).to eq([])
      # AccentlessArtwork is just like BasicArtwork, except that we set :remove_accents to false,
      # so this behaves like the ``old'' version of fulltext_search
      expect(AccentlessArtwork.fulltext_search('cesar').first).to eq(julio)
    end
  end

  context 'with default settings' do
    let!(:flower_myth) { BasicArtwork.create(title: 'Flower Myth') }
    let!(:flowers)     { BasicArtwork.create(title: 'Flowers') }
    let!(:lowered)     { BasicArtwork.create(title: 'Lowered') }
    let!(:cookies)     { BasicArtwork.create(title: 'Cookies') }
    let!(:empty)       { BasicArtwork.create(title: '') }
    let!(:cesar)       { BasicArtwork.create(title: "C\u00e9sar Galicia") }
    let!(:julio)       { BasicArtwork.create(title: 'Julio Cesar Morales') }
    let!(:csar)        { BasicArtwork.create(title: 'Csar') }
    let!(:percent)     { BasicArtwork.create(title: 'Untitled (cal%desert)') }

    it 'returns empty for empties' do
      expect(BasicArtwork.fulltext_search(nil, max_results: 1)).to eq([])
      expect(BasicArtwork.fulltext_search('', max_results: 1)).to eq([])
    end

    it 'finds percents' do
      expect(BasicArtwork.fulltext_search('cal%desert'.force_encoding('ASCII-8BIT'), max_results: 1).first).to eq(percent)
      expect(BasicArtwork.fulltext_search('cal%desert'.force_encoding('UTF-8'), max_results: 1).first).to eq(percent)
    end

    it 'forgets accents' do
      expect(BasicArtwork.fulltext_search('cesar', max_results: 1).first).to eq(cesar)
      expect(BasicArtwork.fulltext_search('cesar g', max_results: 1).first).to eq(cesar)
      expect(BasicArtwork.fulltext_search("C\u00e9sar", max_results: 1).first).to eq(cesar)
      expect(BasicArtwork.fulltext_search("C\303\251sar".force_encoding('UTF-8'), max_results: 1).first).to eq(cesar)
      expect(BasicArtwork.fulltext_search(CGI.unescape('c%C3%A9sar'), max_results: 1).first).to eq(cesar)
      expect(BasicArtwork.fulltext_search(CGI.unescape('c%C3%A9sar'.encode('ASCII-8BIT')), max_results: 1).first).to eq(cesar)
    end

    it 'returns exact matches' do
      expect(BasicArtwork.fulltext_search('Flower Myth', max_results: 1).first).to eq(flower_myth)
      expect(BasicArtwork.fulltext_search('Flowers', max_results: 1).first).to eq(flowers)
      expect(BasicArtwork.fulltext_search('Cookies', max_results: 1).first).to eq(cookies)
      expect(BasicArtwork.fulltext_search('Lowered', max_results: 1).first).to eq(lowered)
    end

    it 'returns exact matches regardless of case' do
      expect(BasicArtwork.fulltext_search('fLOWER mYTH', max_results: 1).first).to eq(flower_myth)
      expect(BasicArtwork.fulltext_search('FLOWERS', max_results: 1).first).to eq(flowers)
      expect(BasicArtwork.fulltext_search('cOOkies', max_results: 1).first).to eq(cookies)
      expect(BasicArtwork.fulltext_search('lOWERED', max_results: 1).first).to eq(lowered)
    end

    it 'returns all relevant results, sorted by relevance' do
      expect(BasicArtwork.fulltext_search('Flowers')).to eq([flowers, flower_myth, lowered])
    end

    it 'prefers prefix matches' do
      expect([flowers, flower_myth]).to include(BasicArtwork.fulltext_search('Floweockies').first)
      expect(BasicArtwork.fulltext_search('Lowers').first).to eq(lowered)
      expect(BasicArtwork.fulltext_search('Cookilowers').first).to eq(cookies)
    end

    it 'returns an empty result set for an empty query' do
      expect(BasicArtwork.fulltext_search('').empty?).to be_truthy
    end

    it "returns an empty result set for a query that doesn't contain any characters in the alphabet" do
      expect(BasicArtwork.fulltext_search('_+=--@!##%#$%%').empty?).to be_truthy
    end

    it 'returns results for a query that contains only a single ngram' do
      expect(BasicArtwork.fulltext_search('coo').first).to eq(cookies)
      expect(BasicArtwork.fulltext_search('c!!!oo').first).to eq(cookies)
    end
  end

  context 'with default settings' do
    let!(:flower_myth) { Gallery::BasicArtwork.create(title: 'Flower Myth') }
    let!(:flowers)     { Gallery::BasicArtwork.create(title: 'Flowers') }
    let!(:lowered)     { Gallery::BasicArtwork.create(title: 'Lowered') }
    let!(:cookies)     { Gallery::BasicArtwork.create(title: 'Cookies') }
    let!(:empty)       { Gallery::BasicArtwork.create(title: '') }

    it 'returns exact matches for model within a module' do
      expect(Gallery::BasicArtwork.fulltext_search('Flower Myth', max_results: 1).first).to eq(flower_myth)
      expect(Gallery::BasicArtwork.fulltext_search('Flowers', max_results: 1).first).to eq(flowers)
      expect(Gallery::BasicArtwork.fulltext_search('Cookies', max_results: 1).first).to eq(cookies)
      expect(Gallery::BasicArtwork.fulltext_search('Lowered', max_results: 1).first).to eq(lowered)
    end
  end

  context 'with default settings' do
    let!(:yellow)             { BasicArtwork.create(title: 'Yellow') }
    let!(:yellow_leaves_2)    { BasicArtwork.create(title: 'Yellow Leaves 2') }
    let!(:yellow_leaves_3)    { BasicArtwork.create(title: 'Yellow Leaves 3') }
    let!(:yellow_leaves_20)   { BasicArtwork.create(title: 'Yellow Leaves 20') }
    let!(:yellow_cup)         { BasicArtwork.create(title: 'Yellow Cup') }

    it 'prefers the best prefix that matches a given string' do
      expect(BasicArtwork.fulltext_search('yellow').first).to eq(yellow)
      expect(BasicArtwork.fulltext_search('yellow leaves', max_results: 3).sort_by(&:title)).to eq( \
        [yellow_leaves_2, yellow_leaves_3, yellow_leaves_20].sort_by(&:title)
      )
      expect(BasicArtwork.fulltext_search('yellow cup').first).to eq(yellow_cup)
    end
  end

  context 'with default settings' do
    let!(:monet) { BasicArtwork.create(title: 'claude monet') }
    let!(:one_month_weather_permitting) { BasicArtwork.create(title: 'one month weather permitting monday') }

    it 'finds better matches within exact strings' do
      expect(BasicArtwork.fulltext_search('monet').first).to eq(monet)
    end
  end

  context 'with default settings' do
    let!(:abc)       { BasicArtwork.create(title: 'abc') }
    let!(:abcd)      { BasicArtwork.create(title: 'abcd') }
    let!(:abcde)     { BasicArtwork.create(title: 'abcde') }
    let!(:abcdef)    { BasicArtwork.create(title: 'abcdef') }
    let!(:abcdefg)   { BasicArtwork.create(title: 'abcdefg') }
    let!(:abcdefgh)  { BasicArtwork.create(title: 'abcdefgh') }

    it 'returns exact matches from a list of similar prefixes' do
      expect(BasicArtwork.fulltext_search('abc').first).to eq(abc)
      expect(BasicArtwork.fulltext_search('abcd').first).to eq(abcd)
      expect(BasicArtwork.fulltext_search('abcde').first).to eq(abcde)
      expect(BasicArtwork.fulltext_search('abcdef').first).to eq(abcdef)
      expect(BasicArtwork.fulltext_search('abcdefg').first).to eq(abcdefg)
      expect(BasicArtwork.fulltext_search('abcdefgh').first).to eq(abcdefgh)
    end
  end

  context 'with an index name specified' do
    let!(:pablo_picasso)       { ExternalArtist.create(full_name: 'Pablo Picasso') }
    let!(:portrait_of_picasso) { ExternalArtwork.create(title: 'Portrait of Picasso') }
    let!(:andy_warhol)         { ExternalArtist.create(full_name: 'Andy Warhol') }
    let!(:warhol)              { ExternalArtwork.create(title: 'Warhol') }
    let!(:empty)               { ExternalArtwork.create(title: '') }

    it 'returns results of different types from the same query' do
      results = ExternalArtwork.fulltext_search('picasso', max_results: 2).map { |result| result }
      expect(results.member?(portrait_of_picasso)).to be_truthy
      expect(results.member?(pablo_picasso)).to be_truthy
      results = ExternalArtist.fulltext_search('picasso', max_results: 2).map { |result| result }
      expect(results.member?(portrait_of_picasso)).to be_truthy
      expect(results.member?(pablo_picasso)).to be_truthy
    end

    it 'returns exact matches' do
      expect(ExternalArtwork.fulltext_search('Pablo Picasso', max_results: 1).first).to eq(pablo_picasso)
      expect(ExternalArtwork.fulltext_search('Portrait of Picasso', max_results: 1).first).to eq(portrait_of_picasso)
      expect(ExternalArtwork.fulltext_search('Andy Warhol', max_results: 1).first).to eq(andy_warhol)
      expect(ExternalArtwork.fulltext_search('Warhol', max_results: 1).first).to eq(warhol)
      expect(ExternalArtist.fulltext_search('Pablo Picasso', max_results: 1).first).to eq(pablo_picasso)
      expect(ExternalArtist.fulltext_search('Portrait of Picasso', max_results: 1).first).to eq(portrait_of_picasso)
      expect(ExternalArtist.fulltext_search('Andy Warhol', max_results: 1).first).to eq(andy_warhol)
      expect(ExternalArtist.fulltext_search('Warhol', max_results: 1).first).to eq(warhol)
    end

    it 'returns exact matches regardless of case' do
      expect(ExternalArtwork.fulltext_search('pABLO pICASSO', max_results: 1).first).to eq(pablo_picasso)
      expect(ExternalArtist.fulltext_search('PORTRAIT OF PICASSO', max_results: 1).first).to eq(portrait_of_picasso)
      expect(ExternalArtwork.fulltext_search('andy warhol', max_results: 1).first).to eq(andy_warhol)
      expect(ExternalArtwork.fulltext_search('wArHoL', max_results: 1).first).to eq(warhol)
    end

    it 'returns all relevant results, sorted by relevance' do
      expect(ExternalArtist.fulltext_search('Pablo Picasso')).to eq([pablo_picasso, portrait_of_picasso])
      expect(ExternalArtwork.fulltext_search('Pablo Picasso')).to eq([pablo_picasso, portrait_of_picasso])
      expect(ExternalArtist.fulltext_search('Portrait of Picasso')).to eq([portrait_of_picasso, pablo_picasso])
      expect(ExternalArtwork.fulltext_search('Portrait of Picasso')).to eq([portrait_of_picasso, pablo_picasso])
      expect(ExternalArtist.fulltext_search('Andy Warhol')).to eq([andy_warhol, warhol])
      expect(ExternalArtwork.fulltext_search('Andy Warhol')).to eq([andy_warhol, warhol])
      expect(ExternalArtist.fulltext_search('Warhol')).to eq([warhol, andy_warhol])
      expect(ExternalArtwork.fulltext_search('Warhol')).to eq([warhol, andy_warhol])
    end

    it 'prefers prefix matches' do
      expect(ExternalArtist.fulltext_search('PabloWarhol').first).to eq(pablo_picasso)
      expect(ExternalArtist.fulltext_search('AndyPicasso').first).to eq(andy_warhol)
    end

    it 'returns an empty result set for an empty query' do
      expect(ExternalArtist.fulltext_search('').empty?).to be_truthy
    end

    it "returns an empty result set for a query that doesn't contain any characters in the alphabet" do
      expect(ExternalArtwork.fulltext_search('#$%!$#*%*').empty?).to be_truthy
    end

    it 'returns results for a query that contains only a single ngram' do
      expect(ExternalArtist.fulltext_search('and').first).to eq(andy_warhol)
    end
  end

  context 'with an index name specified' do
    let!(:andy_warhol)         { ExternalArtist.create(full_name: 'Andy Warhol') }
    let!(:warhol)              { ExternalArtwork.create(title: 'Warhol') }

    it "doesn't blow up if garbage is in the index collection" do
      expect(ExternalArtist.fulltext_search('warhol')).to eq([warhol, andy_warhol])
      index_collection = ExternalArtist.collection.database[ExternalArtist.mongoid_fulltext_config.keys.first]
      index_collection.find('document_id' => warhol.id).each do |idef|
        if Mongoid::Compatibility::Version.mongoid3?
          index_collection.find('_id' => idef['_id']).update('document_id' => Moped::BSON::ObjectId.new)
        elsif Mongoid::Compatibility::Version.mongoid4?
          index_collection.find('_id' => idef['_id']).update('document_id' => BSON::ObjectId.new)
        else
          index_collection.find('_id' => idef['_id']).update_one('document_id' => BSON::ObjectId.new)
        end
      end
      # We should no longer be able to find warhol, but that shouldn't keep it from returning results
      expect(ExternalArtist.fulltext_search('warhol')).to eq([andy_warhol])
    end
  end

  context 'with an index name specified' do
    let!(:pop)                { ExternalArtwork.create(title: 'Pop') }
    let!(:pop_culture)        { ExternalArtwork.create(title: 'Pop Culture') }
    let!(:contemporary_pop)   { ExternalArtwork.create(title: 'Contemporary Pop') }
    let!(:david_poppie)       { ExternalArtist.create(full_name: 'David Poppie') }
    let!(:kung_fu_lollipop)   { ExternalArtwork.create(title: 'Kung-Fu Lollipop') }

    it 'prefers the best prefix that matches a given string' do
      expect(ExternalArtwork.fulltext_search('pop').first).to eq(pop)
      expect(ExternalArtwork.fulltext_search('poppie').first).to eq(david_poppie)
      expect(ExternalArtwork.fulltext_search('pop cult').first).to eq(pop_culture)
      expect(ExternalArtwork.fulltext_search('pop', max_results: 5)[4]).to eq(kung_fu_lollipop)
    end
  end
  context 'with an index name specified' do
    let!(:abc)       { ExternalArtwork.create(title: 'abc') }
    let!(:abcd)      { ExternalArtwork.create(title: 'abcd') }
    let!(:abcde)     { ExternalArtwork.create(title: 'abcde') }
    let!(:abcdef)    { ExternalArtwork.create(title: 'abcdef') }
    let!(:abcdefg)   { ExternalArtwork.create(title: 'abcdefg') }
    let!(:abcdefgh)  { ExternalArtwork.create(title: 'abcdefgh') }

    it 'returns exact matches from a list of similar prefixes' do
      expect(ExternalArtwork.fulltext_search('abc').first).to eq(abc)
      expect(ExternalArtwork.fulltext_search('abcd').first).to eq(abcd)
      expect(ExternalArtwork.fulltext_search('abcde').first).to eq(abcde)
      expect(ExternalArtwork.fulltext_search('abcdef').first).to eq(abcdef)
      expect(ExternalArtwork.fulltext_search('abcdefg').first).to eq(abcdefg)
      expect(ExternalArtwork.fulltext_search('abcdefgh').first).to eq(abcdefgh)
    end
  end

  context 'with an index name specified' do
    it "cleans up item from the index after they're destroyed" do
      foobar = ExternalArtwork.create(title: 'foobar')
      barfoo = ExternalArtwork.create(title: 'barfoo')
      expect(ExternalArtwork.fulltext_search('foobar')).to eq([foobar, barfoo])
      foobar.destroy
      expect(ExternalArtwork.fulltext_search('foobar')).to eq([barfoo])
      barfoo.destroy
      expect(ExternalArtwork.fulltext_search('foobar')).to eq([])
    end
  end

  context 'with an index name specified and no fields provided to index' do
    let!(:big_bang) { ExternalArtworkNoFieldsSupplied.create(title: 'Big Bang', artist: 'David Poppie', year: '2009') }

    it 'indexes the string returned by to_s' do
      expect(ExternalArtworkNoFieldsSupplied.fulltext_search('big bang').first).to eq(big_bang)
      expect(ExternalArtworkNoFieldsSupplied.fulltext_search('poppie').first).to eq(big_bang)
      expect(ExternalArtworkNoFieldsSupplied.fulltext_search('2009').first).to eq(big_bang)
    end
  end

  context 'with multiple indexes defined' do
    let!(:pop)                { MultiExternalArtwork.create(title: 'Pop', year: '1970', artist: 'Joe Schmoe') }
    let!(:pop_culture)        { MultiExternalArtwork.create(title: 'Pop Culture', year: '1977', artist: 'Jim Schmoe') }
    let!(:contemporary_pop)   { MultiExternalArtwork.create(title: 'Contemporary Pop', year: '1800', artist: 'Bill Schmoe') }
    let!(:kung_fu_lollipop)   { MultiExternalArtwork.create(title: 'Kung-Fu Lollipop', year: '2006', artist: 'Michael Anderson') }

    it 'allows searches to hit a particular index' do
      title_results = MultiExternalArtwork.fulltext_search('pop', index: 'mongoid_fulltext.titles').sort_by(&:title)
      expect(title_results).to eq([pop, pop_culture, contemporary_pop, kung_fu_lollipop].sort_by(&:title))
      year_results = MultiExternalArtwork.fulltext_search('197', index: 'mongoid_fulltext.years').sort_by(&:title)
      expect(year_results).to eq([pop, pop_culture].sort_by(&:title))
      all_results = MultiExternalArtwork.fulltext_search('1800 and', index: 'mongoid_fulltext.all').sort_by(&:title)
      expect(all_results).to eq([contemporary_pop, kung_fu_lollipop].sort_by(&:title))
    end

    it "should raise an error if you don't specify which index to search with" do
      expect { MultiExternalArtwork.fulltext_search('foobar') }.to raise_error(Mongoid::FullTextSearch::UnspecifiedIndexError)
    end
  end

  context 'with multiple fields indexed and the same index used by multiple models' do
    let!(:andy_warhol)         { MultiFieldArtist.create(full_name: 'Andy Warhol', birth_year: '1928') }
    let!(:warhol)              { MultiFieldArtwork.create(title: 'Warhol', year: '2010') }
    let!(:pablo_picasso)       { MultiFieldArtist.create(full_name: 'Pablo Picasso', birth_year: '1881') }
    let!(:portrait_of_picasso) { MultiFieldArtwork.create(title: 'Portrait of Picasso', year: '1912') }

    it 'allows searches across all models on both fields indexed' do
      expect(MultiFieldArtist.fulltext_search('2010').first).to eq(warhol)
      expect(MultiFieldArtist.fulltext_search('andy').first).to eq(andy_warhol)
      expect(MultiFieldArtist.fulltext_search('pablo').first).to eq(pablo_picasso)
      expect(MultiFieldArtist.fulltext_search('1881').first).to eq(pablo_picasso)
      expect(MultiFieldArtist.fulltext_search('portrait 1912').first).to eq(portrait_of_picasso)

      expect(MultiFieldArtwork.fulltext_search('2010').first).to eq(warhol)
      expect(MultiFieldArtwork.fulltext_search('andy').first).to eq(andy_warhol)
      expect(MultiFieldArtwork.fulltext_search('pablo').first).to eq(pablo_picasso)
      expect(MultiFieldArtwork.fulltext_search('1881').first).to eq(pablo_picasso)
      expect(MultiFieldArtwork.fulltext_search('portrait 1912').first).to eq(portrait_of_picasso)
    end
  end
  context 'with filters applied to multiple models' do
    let!(:foobar_artwork)    { FilteredArtwork.create(title: 'foobar') }
    let!(:barfoo_artwork)    { FilteredArtwork.create(title: 'barfoo') }
    let!(:foobar_artist)     { FilteredArtist.create(full_name: 'foobar') }
    let!(:barfoo_artist)     { FilteredArtist.create(full_name: 'barfoo') }

    it 'allows filtered searches' do
      expect(FilteredArtwork.fulltext_search('foobar', is_artwork: true)).to eq([foobar_artwork, barfoo_artwork])
      expect(FilteredArtist.fulltext_search('foobar', is_artwork: true)).to eq([foobar_artwork, barfoo_artwork])

      expect(FilteredArtwork.fulltext_search('foobar', is_artwork: true, is_foobar: true)).to eq([foobar_artwork])
      expect(FilteredArtwork.fulltext_search('foobar', is_artwork: true, is_foobar: false)).to eq([barfoo_artwork])
      expect(FilteredArtwork.fulltext_search('foobar', is_artwork: false, is_foobar: true)).to eq([foobar_artist])
      expect(FilteredArtwork.fulltext_search('foobar', is_artwork: false, is_foobar: false)).to eq([barfoo_artist])

      expect(FilteredArtist.fulltext_search('foobar', is_artwork: true, is_foobar: true)).to eq([foobar_artwork])
      expect(FilteredArtist.fulltext_search('foobar', is_artwork: true, is_foobar: false)).to eq([barfoo_artwork])
      expect(FilteredArtist.fulltext_search('foobar', is_artwork: false, is_foobar: true)).to eq([foobar_artist])
      expect(FilteredArtist.fulltext_search('foobar', is_artwork: false, is_foobar: false)).to eq([barfoo_artist])
    end
  end

  context 'with different filters applied to multiple models' do
    let!(:foo_artwork)    { FilteredArtwork.create(title: 'foo') }
    let!(:bar_artist)     { FilteredArtist.create(full_name: 'bar') }
    let!(:baz_other)      { FilteredOther.create(name: 'baz') }

    # These three models are all indexed by the same mongoid_fulltext index, but have different filters
    # applied. The index created on the mongoid_fulltext collection should include the ngram and score
    # fields as well as the union of all the filter fields to allow for efficient lookups.

    it 'creates a proper index for searching efficiently' do
      [FilteredArtwork, FilteredArtist, FilteredOther].each(&:create_indexes)
      index_collection = FilteredArtwork.collection.database['mongoid_fulltext.artworks_and_artists']
      ngram_indexes = []
      index_collection.indexes.each { |idef| ngram_indexes << idef if idef['key'].key?('ngram') }
      expect(ngram_indexes.length).to eq(1)
      keys = ngram_indexes.first['key'].keys
      expected_keys = ['ngram', 'score', 'filter_values.is_fuzzy', 'filter_values.is_awesome',
                       'filter_values.is_foobar', 'filter_values.is_artwork', 'filter_values.is_artist', 'filter_values.colors?'].sort
      expect(keys.sort).to eq(expected_keys)
    end
  end

  context 'with partitions applied to a model' do
    let!(:artist_2) { PartitionedArtist.create(full_name: 'foobar', exhibitions: ['Art Basel 2011', 'Armory NY']) }
    let!(:artist_1) { PartitionedArtist.create(full_name: 'foobar', exhibitions: ['Art Basel 2011']) }
    let!(:artist_0) { PartitionedArtist.create(full_name: 'foobar', exhibitions: []) }

    it 'allows partitioned searches' do
      artists_by_exhibition_length = [artist_0, artist_1, artist_2].sort_by { |x| x.exhibitions.length }
      expect(PartitionedArtist.fulltext_search('foobar').sort_by { |x| x.exhibitions.length }).to eq(artists_by_exhibition_length)
      expect(PartitionedArtist.fulltext_search('foobar', exhibitions: ['Armory NY'])).to eq([artist_2])
      art_basel_only = PartitionedArtist.fulltext_search('foobar', exhibitions: ['Art Basel 2011']).sort_by { |x| x.exhibitions.length }
      expect(art_basel_only).to eq([artist_1, artist_2].sort_by { |x| x.exhibitions.length })
      expect(PartitionedArtist.fulltext_search('foobar', exhibitions: ['Art Basel 2011', 'Armory NY'])).to eq([artist_2])
    end
  end

  context 'using search options' do
    let!(:patterns)    { BasicArtwork.create(title: 'Flower Patterns') }
    let!(:flowers)     { BasicArtwork.create(title: 'Flowers') }

    it 'returns max_results' do
      expect(BasicArtwork.fulltext_search('flower', max_results: 1).length).to eq(1)
    end

    it 'returns scored results' do
      results = BasicArtwork.fulltext_search('flowers', return_scores: true)
      first_result = results[0]
      expect(first_result.is_a?(Array)).to be_truthy
      expect(first_result.size).to eq(2)
      expect(first_result[0]).to eq(flowers)
      expect(first_result[1].is_a?(Float)).to be_truthy
    end
  end

  context 'with various word separators' do
    let!(:hard_edged_painting)   { BasicArtwork.create(title: 'Hard-edged painting') }
    let!(:edgy_painting)         { BasicArtwork.create(title: 'Edgy painting') }
    let!(:hard_to_find_ledge)    { BasicArtwork.create(title: 'Hard to find ledge') }

    it 'should treat dashes as word separators, giving a score boost to each dash-separated word' do
      expect(BasicArtwork.fulltext_search('hard-edged').first).to eq(hard_edged_painting)
      expect(BasicArtwork.fulltext_search('hard edge').first).to eq(hard_edged_painting)
      expect(BasicArtwork.fulltext_search('hard edged').first).to eq(hard_edged_painting)
    end
  end

  context 'returning scores' do
    # Since we return scores, let's make some weak guarantees about what they actually mean

    let!(:mao_yan)      { ExternalArtist.create(full_name: 'Mao Yan') }
    let!(:mao)          { ExternalArtwork.create(title: 'Mao by Andy Warhol') }
    let!(:maox)         { ExternalArtwork.create(title: 'Maox by Randy Morehall') }
    let!(:somao)        { ExternalArtwork.create(title: 'Somao by Randy Morehall') }

    it "returns basic matches that don't match a whole word and aren't prefixes with score < 1" do
      %w(paox porehall).each do |query|
        results = ExternalArtist.fulltext_search(query, return_scores: true)
        expect(results.length).to be > 0
        expect(results.map { |result| result[-1] }.inject(true) { |accum, item| accum &= (item < 1) }).to be_truthy
      end
    end

    it 'returns prefix matches with a score >= 1 but < 2' do
      %w(warho rand).each do |query|
        results = ExternalArtist.fulltext_search(query, return_scores: true)
        expect(results.length).to be > 0
        expect(results.map { |result| result[-1] if result[0].to_s.starts_with?(query) }.compact.inject(true) { |accum, item| accum &= (item >= 1 && item < 2) }).to be_truthy
      end
    end

    it 'returns full-word matches with a score >= 2' do
      %w(andy warhol mao).each do |query|
        results = ExternalArtist.fulltext_search(query, return_scores: true)
        expect(results.length).to be > 0
        expect(results.map { |result| result[-1] if result[0].to_s.split(' ').member?(query) }.compact.inject(true) { |accum, item| accum &= (item >= 2) }).to be_truthy
      end
    end
  end

  context 'with stop words defined' do
    let!(:flowers)      { StopwordsArtwork.create(title: 'Flowers by Andy Warhol') }
    let!(:many_ands)    { StopwordsArtwork.create(title: 'Foo and bar and baz and foobar') }
    let!(:harry)        { StopwordsArtwork.create(title: 'Harry in repose by JK Rowling') }

    it "doesn't give a full-word score boost to stopwords" do
      expect(StopwordsArtwork.fulltext_search('andy').map(&:title)).to eq([flowers.title, many_ands.title])
      expect(StopwordsArtwork.fulltext_search('warhol and other stuff').map(&:title)).to eq([flowers.title, many_ands.title])
    end

    it 'allows searching on words that are more than one letter, less than the ngram length and not stopwords' do
      expect(StopwordsArtwork.fulltext_search('jk').map(&:title)).to eq([harry.title])
      expect(StopwordsArtwork.fulltext_search('by').map(&:title)).to eq([])
    end
  end

  context 'indexing short prefixes' do
    let!(:dimethyl_mercury)   { ShortPrefixesArtwork.create(title: 'Dimethyl Mercury by Damien Hirst') }
    let!(:volume)             { ShortPrefixesArtwork.create(title: 'Volume by Dadamaino') }
    let!(:damaged)            { ShortPrefixesArtwork.create(title: 'Damaged: Photographs from the Chicago Daily News 1902-1933 (Governor) by Lisa Oppenheim') }
    let!(:frozen)             { ShortPrefixesArtwork.create(title: 'Frozen Fountain XXX by Evelyn Rosenberg') }
    let!(:skull)              { ShortPrefixesArtwork.create(title: 'Skull by Andy Warhol') }

    it 'finds the most relevant items with prefix indexing' do
      expect(ShortPrefixesArtwork.fulltext_search('damien').first).to eq(dimethyl_mercury)
      expect(ShortPrefixesArtwork.fulltext_search('dami').first).to eq(dimethyl_mercury)
      expect(ShortPrefixesArtwork.fulltext_search('dama').first).to eq(damaged)
      expect(ShortPrefixesArtwork.fulltext_search('dam').first).not_to eq(volume)
      expect(ShortPrefixesArtwork.fulltext_search('dadamaino').first).to eq(volume)
      expect(ShortPrefixesArtwork.fulltext_search('kull').first).to eq(skull)
    end

    it "doesn't index prefixes of stopwords" do
      # damaged has the word "from" in it, which shouldn't get indexed.
      expect(ShortPrefixesArtwork.fulltext_search('fro')).to eq([frozen])
    end

    it 'does index prefixes that would be stopwords taken alone' do
      # skull has the word "andy" in it, which should get indexed as "and" even though "and" is a stopword
      expect(ShortPrefixesArtwork.fulltext_search('and')).to eq([skull])
    end
  end

  context 'remove_from_ngram_index' do
    let!(:flowers1)     { BasicArtwork.create(title: 'Flowers 1') }
    let!(:flowers2)     { BasicArtwork.create(title: 'Flowers 1') }

    it 'removes all records from the index' do
      BasicArtwork.remove_from_ngram_index
      expect(BasicArtwork.fulltext_search('flower').length).to eq(0)
    end

    it 'removes a single record from the index' do
      flowers1.remove_from_ngram_index
      expect(BasicArtwork.fulltext_search('flower').length).to eq(1)
    end
  end

  context 'update_ngram_index' do
    let!(:flowers1)     { BasicArtwork.create(title: 'Flowers 1') }
    let!(:flowers2)     { BasicArtwork.create(title: 'Flowers 2') }

    context 'when config[:update_if] exists' do
      let(:painting)          { BasicArtwork.new title: 'Painting' }
      let(:conditional_index) { BasicArtwork.mongoid_fulltext_config['mongoid_fulltext.index_conditional'] }

      before(:each) do
        BasicArtwork.class_eval do
          fulltext_search_in :title, index_name: 'mongoid_fulltext.index_conditional'
        end
      end

      after(:all) do
        # Moped 1.0.0rc raises an error when removing a collection that does not exist
        # Will be fixed soon.
        begin
          Mongoid.default_session['mongoid_fulltext.index_conditional'].drop
        rescue Moped::Errors::OperationFailure => e
        end
        BasicArtwork.mongoid_fulltext_config.delete 'mongoid_fulltext.index_conditional'
      end

      context 'and is a symbol' do
        before(:each) do
          conditional_index[:update_if] = :persisted?
        end

        context 'when sending the symbol to the document evaluates to false' do
          it "doesn't update the index for the document" do
            painting.update_ngram_index
            expect(BasicArtwork.fulltext_search('painting', index: 'mongoid_fulltext.index_conditional').length).to be 0
          end
        end
      end

      context 'and is a string' do
        before(:each) do
          conditional_index[:update_if] = 'false'
        end

        context "when evaluating the string within the document's instance evaluates to false" do
          it "doesn't update the index for the document" do
            painting.update_ngram_index
            expect(BasicArtwork.fulltext_search('painting', index: 'mongoid_fulltext.index_conditional').length).to be 0
          end
        end
      end

      context 'and is a proc' do
        before(:each) do
          conditional_index[:update_if] = proc { false }
        end

        context "when evaluating the string within the document's instance evaluates to false" do
          it "doesn't update the index for the document" do
            painting.update_ngram_index
            expect(BasicArtwork.fulltext_search('painting', index: 'mongoid_fulltext.index_conditional').length).to be 0
          end
        end
      end

      context 'and is not a symbol, string, or proc' do
        before(:each) do
          conditional_index[:update_if] = %w(this isn't a symbol, string, or proc)
        end

        it "doesn't update the index for the document" do
          painting.update_ngram_index
          expect(BasicArtwork.fulltext_search('painting', index: 'mongoid_fulltext.index_conditional').length).to be 0
        end
      end
    end

    context 'from scratch' do
      before(:each) do
        Mongoid.default_session['mongoid_fulltext.index_basicartwork_0'].drop
      end

      it 'updates index on a single record' do
        flowers1.update_ngram_index
        expect(BasicArtwork.fulltext_search('flower').length).to eq(1)
      end

      it 'updates index on all records' do
        BasicArtwork.update_ngram_index
        expect(BasicArtwork.fulltext_search('flower').length).to eq(2)
      end
    end

    context 'incremental' do
      it 'removes an existing record' do
        coll = Mongoid.default_session['mongoid_fulltext.index_basicartwork_0']
        if Mongoid::Compatibility::Version.mongoid5?
          coll.find('document_id' => flowers1._id).delete_many
        else
          coll.find('document_id' => flowers1._id).remove_all
        end
        expect(coll.find('document_id' => flowers1._id).first).to be nil
        flowers1.update_ngram_index
      end
    end

    context 'mongoid indexes' do
      it 'can re-create dropped indexes' do
        # there're no indexes by default as Mongoid.autocreate_indexes is set to false
        # but mongo will automatically attempt to index _id in the background
        expect(Mongoid.default_session['mongoid_fulltext.index_basicartwork_0'].indexes.count).to be <= 1
        BasicArtwork.create_indexes
        expected_indexes = %w(_id_ fts_index document_id_1).sort
        current_indexes = []
        Mongoid.default_session['mongoid_fulltext.index_basicartwork_0'].indexes.each do |idef|
          current_indexes << idef['name']
        end
        expect(current_indexes.sort).to eq(expected_indexes)
      end

      it "doesn't fail on models that don't have a fulltext index" do
        expect { HiddenDragon.create_indexes }.not_to raise_error
      end

      it "doesn't blow up when the Mongoid.logger is set to false" do
        Mongoid.logger = false
        BasicArtwork.create_indexes
      end
    end
  end

  context 'batched reindexing' do
    let!(:flowers1) { DelayedArtwork.create(title: 'Flowers 1') }

    it 'should not rebuild index until explicitly invoked' do
      expect(DelayedArtwork.fulltext_search('flowers').length).to eq(0)
      DelayedArtwork.update_ngram_index
      expect(DelayedArtwork.fulltext_search('flowers').length).to eq(1)
    end
  end

  # For =~ operator documentation
  # https://github.com/dchelimsky/rspec/blob/master/lib/spec/matchers/match_array.rb#L53

  context 'with artwork that returns an array of colors as a filter' do
    let!(:title) { 'title' }
    let!(:nomatch) { 'nomatch' }
    let!(:red) { 'red' }
    let!(:green) { 'green' }
    let!(:blue) { 'blue' }
    let!(:yellow) { 'yellow' }
    let!(:brown) { 'brown' }

    let!(:rgb_artwork) { FilteredArtwork.create(title: "#{title} rgb", colors: [red, green, blue]) }
    let!(:holiday_artwork) { FilteredArtwork.create(title: "#{title} holiday", colors: [red, green]) }
    let!(:aqua_artwork) { FilteredArtwork.create(title: "#{title} aqua", colors: [green, blue]) }

    context 'with a fulltext search passing red, green, and blue to the colors filter' do
      it 'should return the rgb artwork' do
        expect(FilteredArtwork.fulltext_search(title, colors?: [red, green, blue])).to eq([rgb_artwork])
      end
    end

    context 'with a fulltext search passing blue and red to the colors filter' do
      it 'should return the rgb artwork' do
        expect(FilteredArtwork.fulltext_search(title, colors?: [blue, red])).to eq([rgb_artwork])
      end
    end

    context 'with a fulltext search passing green to the colors filter' do
      it 'should return all artwork' do
        expect(FilteredArtwork.fulltext_search(title, colors?: [green])).to match_array([rgb_artwork, holiday_artwork, aqua_artwork])
      end
    end

    context 'with a fulltext search passing no colors to the filter' do
      it 'should return all artwork' do
        expect(FilteredArtwork.fulltext_search(title)).to match_array([rgb_artwork, holiday_artwork, aqua_artwork])
      end
    end

    context 'with a fulltext search passing green and yellow to the colors filter' do
      it 'should return no artwork' do
        expect(FilteredArtwork.fulltext_search(title, colors?: [green, yellow])).to eq([])
      end
    end

    context 'with the query operator overridden to use $in instead of the default $all' do
      context 'with a fulltext search passing green and yellow to the colors filter' do
        it 'should return all of the artwork' do
          expect(FilteredArtwork.fulltext_search(title, colors?: { any: [green, yellow] })).to match_array([rgb_artwork, holiday_artwork, aqua_artwork])
        end
      end

      context 'with a fulltext search passing brown and yellow to the colors filter' do
        it 'should return none of the artwork' do
          expect(FilteredArtwork.fulltext_search(title, colors?: { any: [brown, yellow] })).to eq([])
        end
      end

      context 'with a fulltext search passing blue to the colors filter' do
        it 'should return the rgb and aqua artwork' do
          expect(FilteredArtwork.fulltext_search(title, colors?: { any: [blue] })).to eq([rgb_artwork, aqua_artwork])
        end
      end

      context "with a fulltext search term that won't match" do
        it 'should return none of the artwork' do
          expect(FilteredArtwork.fulltext_search(nomatch, colors?: { any: [green, yellow] })).to eq([])
        end
      end
    end

    context 'with the query operator overridden to use $all' do
      context 'with a fulltext search passing red, green, and blue to the colors filter' do
        it 'should return the rgb artwork' do
          expect(FilteredArtwork.fulltext_search(title, colors?: { all: [red, green, blue] })).to eq([rgb_artwork])
        end
      end

      context 'with a fulltext search passing green to the colors filter' do
        it 'should return all artwork' do
          expect(FilteredArtwork.fulltext_search(title, colors?: { all: [green] })).to match_array([rgb_artwork, holiday_artwork, aqua_artwork])
        end
      end
    end

    context 'with an unknown query operator used to override the default $all' do
      context 'with a fulltext search passing red, green, and blue to the colors filter' do
        it 'should raise an error' do
          expect do
            FilteredArtwork.fulltext_search(title, colors?: { unknown: [red, green, blue] })
          end.to raise_error(Mongoid::FullTextSearch::UnknownFilterQueryOperator)
        end
      end
    end

    context 'should properly work with non-latin strings (i.e. cyrillic)' do
      let!(:morning) { RussianArtwork.create(title: 'Утро в сосновом лесу Шишкин Morning in a Pine Forest Shishkin') }

      it 'should find a match if query is non-latin string' do
        # RussianArtwork is just like BasicArtwork, except that we set :alphabet to
        # 'abcdefghijklmnopqrstuvwxyz0123456789абвгдежзиклмнопрстуфхцчшщъыьэюя'
        expect(RussianArtwork.fulltext_search('shishkin').first).to eq(morning)
        expect(RussianArtwork.fulltext_search('шишкин').first).to eq(morning)
      end
    end
  end
end
