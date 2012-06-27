# coding: utf-8
require 'spec_helper'

module Mongoid
  describe FullTextSearch do

    context "with several config options defined" do

      let!(:abcdef) { AdvancedArtwork.create(:title => 'abcdefg hijklmn') }
      let!(:cesar) { AccentlessArtwork.create(:title => "C\u00e9sar Galicia") }
      let!(:julio) { AccentlessArtwork.create(:title => "Julio Cesar Morales") }

      it "should recognize all options" do
        # AdvancedArtwork is defined with an ngram_width of 4 and a different alphabet (abcdefg)
        AdvancedArtwork.fulltext_search('abc').should == []
        AdvancedArtwork.fulltext_search('abcd').first.should == abcdef
        AdvancedArtwork.fulltext_search('defg').first.should == abcdef
        AdvancedArtwork.fulltext_search('hijklmn').should == []
        # AccentlessArtwork is just like BasicArtwork, except that we set :remove_accents to false,
        # so this behaves like the ``old'' version of fulltext_search
        AccentlessArtwork.fulltext_search("cesar").first.should == julio
      end

    end
    
    context "with default settings" do
      
      let!(:flower_myth) { BasicArtwork.create(:title => 'Flower Myth') }
      let!(:flowers)     { BasicArtwork.create(:title => 'Flowers') }
      let!(:lowered)     { BasicArtwork.create(:title => 'Lowered') }
      let!(:cookies)     { BasicArtwork.create(:title => 'Cookies') }
      let!(:empty)       { BasicArtwork.create(:title => '') }
      let!(:cesar)       { BasicArtwork.create(:title => "C\u00e9sar Galicia") }
      let!(:julio)       { BasicArtwork.create(:title => "Julio Cesar Morales") }
      let!(:csar)        { BasicArtwork.create(:title => "Csar") }
      let!(:percent)     { BasicArtwork.create(:title => "Untitled (cal%desert)") }
      
      it "returns empty for empties" do
        BasicArtwork.fulltext_search(nil, :max_results => 1).should == []
        BasicArtwork.fulltext_search("", :max_results => 1).should == []
      end
      
      it "finds percents" do
        BasicArtwork.fulltext_search("cal%desert".force_encoding("ASCII-8BIT"), :max_results => 1).first.should == percent
        BasicArtwork.fulltext_search("cal%desert".force_encoding("UTF-8"), :max_results => 1).first.should == percent
      end
      
      it "forgets accents" do
        BasicArtwork.fulltext_search('cesar', :max_results => 1).first.should == cesar
        BasicArtwork.fulltext_search('cesar g', :max_results => 1).first.should == cesar
        BasicArtwork.fulltext_search("C\u00e9sar", :max_results => 1).first.should == cesar
        BasicArtwork.fulltext_search("C\303\251sar".force_encoding("UTF-8"), :max_results => 1).first.should == cesar
        BasicArtwork.fulltext_search(CGI.unescape("c%C3%A9sar"), :max_results => 1).first.should == cesar
        BasicArtwork.fulltext_search(CGI.unescape("c%C3%A9sar".encode("ASCII-8BIT")), :max_results => 1).first.should == cesar
      end

      it "returns exact matches" do
        BasicArtwork.fulltext_search('Flower Myth', :max_results => 1).first.should == flower_myth
        BasicArtwork.fulltext_search('Flowers', :max_results => 1).first.should == flowers
        BasicArtwork.fulltext_search('Cookies', :max_results => 1).first.should == cookies
        BasicArtwork.fulltext_search('Lowered', :max_results => 1).first.should == lowered
      end

      it "returns exact matches regardless of case" do
        BasicArtwork.fulltext_search('fLOWER mYTH', :max_results => 1).first.should == flower_myth
        BasicArtwork.fulltext_search('FLOWERS', :max_results => 1).first.should == flowers
        BasicArtwork.fulltext_search('cOOkies', :max_results => 1).first.should == cookies
        BasicArtwork.fulltext_search('lOWERED', :max_results => 1).first.should == lowered
      end

      it "returns all relevant results, sorted by relevance" do
        BasicArtwork.fulltext_search('Flowers').should == [flowers, flower_myth, lowered]
      end

      it "prefers prefix matches" do
        [flowers, flower_myth].should include(BasicArtwork.fulltext_search('Floweockies').first)
        BasicArtwork.fulltext_search('Lowers').first.should == lowered
        BasicArtwork.fulltext_search('Cookilowers').first.should == cookies
      end

      it "returns an empty result set for an empty query" do
        BasicArtwork.fulltext_search('').empty?.should be_true
      end

      it "returns an empty result set for a query that doesn't contain any characters in the alphabet" do
        BasicArtwork.fulltext_search('_+=--@!##%#$%%').empty?.should be_true
      end

      it "returns results for a query that contains only a single ngram" do
        BasicArtwork.fulltext_search('coo').first.should == cookies
        BasicArtwork.fulltext_search('c!!!oo').first.should == cookies
      end
            
    end
    
    context "with default settings" do
      
      let!(:flower_myth) { Gallery::BasicArtwork.create(:title => 'Flower Myth') }
      let!(:flowers)     { Gallery::BasicArtwork.create(:title => 'Flowers') }
      let!(:lowered)     { Gallery::BasicArtwork.create(:title => 'Lowered') }
      let!(:cookies)     { Gallery::BasicArtwork.create(:title => 'Cookies') }
      let!(:empty)       { Gallery::BasicArtwork.create(:title => '') }
      
      it "returns exact matches for model within a module" do
        Gallery::BasicArtwork.fulltext_search('Flower Myth', :max_results => 1).first.should == flower_myth
        Gallery::BasicArtwork.fulltext_search('Flowers', :max_results => 1).first.should == flowers
        Gallery::BasicArtwork.fulltext_search('Cookies', :max_results => 1).first.should == cookies
        Gallery::BasicArtwork.fulltext_search('Lowered', :max_results => 1).first.should == lowered
      end
      
    end

    context "with default settings" do

      let!(:yellow)             { BasicArtwork.create(:title => 'Yellow') }
      let!(:yellow_leaves_2)    { BasicArtwork.create(:title => 'Yellow Leaves 2') }
      let!(:yellow_leaves_3)    { BasicArtwork.create(:title => 'Yellow Leaves 3') }
      let!(:yellow_leaves_20)   { BasicArtwork.create(:title => 'Yellow Leaves 20') }
      let!(:yellow_cup)         { BasicArtwork.create(:title => 'Yellow Cup') }

      it "prefers the best prefix that matches a given string" do
        BasicArtwork.fulltext_search('yellow').first.should == yellow
        BasicArtwork.fulltext_search('yellow leaves', :max_results => 3).sort_by{ |x| x.title }.should == \
          [yellow_leaves_2, yellow_leaves_3, yellow_leaves_20].sort_by{ |x| x.title }
        BasicArtwork.fulltext_search('yellow cup').first.should == yellow_cup
      end
      
    end
    
    context "with default settings" do
      let!(:monet)             { BasicArtwork.create(:title => 'claude monet') }
      let!(:one_month_weather_permitting)  { BasicArtwork.create(:title => 'one month weather permitting monday') }

      it "finds better matches within exact strings" do
        BasicArtwork.fulltext_search('monet').first.should == monet
      end
    end
    
    context "with default settings" do
      
      let!(:abc)       { BasicArtwork.create(:title => "abc") }
      let!(:abcd)      { BasicArtwork.create(:title => "abcd") }
      let!(:abcde)     { BasicArtwork.create(:title => "abcde") }
      let!(:abcdef)    { BasicArtwork.create(:title => "abcdef") }
      let!(:abcdefg)   { BasicArtwork.create(:title => "abcdefg") }
      let!(:abcdefgh)  { BasicArtwork.create(:title => "abcdefgh") }
      
      it "returns exact matches from a list of similar prefixes" do
        BasicArtwork.fulltext_search('abc').first.should == abc
        BasicArtwork.fulltext_search('abcd').first.should == abcd
        BasicArtwork.fulltext_search('abcde').first.should == abcde
        BasicArtwork.fulltext_search('abcdef').first.should == abcdef
        BasicArtwork.fulltext_search('abcdefg').first.should == abcdefg
        BasicArtwork.fulltext_search('abcdefgh').first.should == abcdefgh
      end

    end
    
    context "with an index name specified" do
      let!(:pablo_picasso)       { ExternalArtist.create(:full_name => 'Pablo Picasso') }
      let!(:portrait_of_picasso) { ExternalArtwork.create(:title => 'Portrait of Picasso') }
      let!(:andy_warhol)         { ExternalArtist.create(:full_name => 'Andy Warhol') }
      let!(:warhol)              { ExternalArtwork.create(:title => 'Warhol') }
      let!(:empty)               { ExternalArtwork.create(:title => '') }

      it "returns results of different types from the same query" do
        results = ExternalArtwork.fulltext_search('picasso', :max_results => 2).map{ |result| result }
        results.member?(portrait_of_picasso).should be_true
        results.member?(pablo_picasso).should be_true
        results = ExternalArtist.fulltext_search('picasso', :max_results => 2).map{ |result| result }
        results.member?(portrait_of_picasso).should be_true
        results.member?(pablo_picasso).should be_true
      end

      it "returns exact matches" do
        ExternalArtwork.fulltext_search('Pablo Picasso', :max_results => 1).first.should == pablo_picasso
        ExternalArtwork.fulltext_search('Portrait of Picasso', :max_results => 1).first.should == portrait_of_picasso
        ExternalArtwork.fulltext_search('Andy Warhol', :max_results => 1).first.should == andy_warhol
        ExternalArtwork.fulltext_search('Warhol', :max_results => 1).first.should == warhol
        ExternalArtist.fulltext_search('Pablo Picasso', :max_results => 1).first.should == pablo_picasso
        ExternalArtist.fulltext_search('Portrait of Picasso', :max_results => 1).first.should == portrait_of_picasso
        ExternalArtist.fulltext_search('Andy Warhol', :max_results => 1).first.should == andy_warhol
        ExternalArtist.fulltext_search('Warhol', :max_results => 1).first.should == warhol
      end

      it "returns exact matches regardless of case" do
        ExternalArtwork.fulltext_search('pABLO pICASSO', :max_results => 1).first.should == pablo_picasso
        ExternalArtist.fulltext_search('PORTRAIT OF PICASSO', :max_results => 1).first.should == portrait_of_picasso
        ExternalArtwork.fulltext_search('andy warhol', :max_results => 1).first.should == andy_warhol
        ExternalArtwork.fulltext_search('wArHoL', :max_results => 1).first.should == warhol
      end

      it "returns all relevant results, sorted by relevance" do
        ExternalArtist.fulltext_search('Pablo Picasso').should == [pablo_picasso, portrait_of_picasso]
        ExternalArtwork.fulltext_search('Pablo Picasso').should == [pablo_picasso, portrait_of_picasso]
        ExternalArtist.fulltext_search('Portrait of Picasso').should == [portrait_of_picasso, pablo_picasso]
        ExternalArtwork.fulltext_search('Portrait of Picasso').should == [portrait_of_picasso, pablo_picasso]
        ExternalArtist.fulltext_search('Andy Warhol').should == [andy_warhol, warhol]
        ExternalArtwork.fulltext_search('Andy Warhol').should == [andy_warhol, warhol]
        ExternalArtist.fulltext_search('Warhol').should == [warhol, andy_warhol]
        ExternalArtwork.fulltext_search('Warhol').should == [warhol, andy_warhol]
      end

      it "prefers prefix matches" do
        ExternalArtist.fulltext_search('PabloWarhol').first.should == pablo_picasso
        ExternalArtist.fulltext_search('AndyPicasso').first.should == andy_warhol
      end

      it "returns an empty result set for an empty query" do
        ExternalArtist.fulltext_search('').empty?.should be_true
      end

      it "returns an empty result set for a query that doesn't contain any characters in the alphabet" do
        ExternalArtwork.fulltext_search('#$%!$#*%*').empty?.should be_true
      end

      it "returns results for a query that contains only a single ngram" do
        ExternalArtist.fulltext_search('and').first.should == andy_warhol
      end

    end
    
    context "with an index name specified" do

      let!(:andy_warhol)         { ExternalArtist.create(:full_name => 'Andy Warhol') }
      let!(:warhol)              { ExternalArtwork.create(:title => 'Warhol') }

      it "doesn't blow up if garbage is in the index collection" do
        ExternalArtist.fulltext_search('warhol').should == [warhol, andy_warhol]
        index_collection = ExternalArtist.collection.database[ExternalArtist.mongoid_fulltext_config.keys.first]
        index_collection.find('document_id' => warhol.id).each do |idef|
          index_collection.find('_id' => idef['_id']).update('document_id' => BSON::ObjectId.new)
        end
        # We should no longer be able to find warhol, but that shouldn't keep it from returning results
        ExternalArtist.fulltext_search('warhol').should == [andy_warhol]
      end
      
    end
    
    context "with an index name specified" do

      let!(:pop)                { ExternalArtwork.create(:title => 'Pop') }
      let!(:pop_culture)        { ExternalArtwork.create(:title => 'Pop Culture') }
      let!(:contemporary_pop)   { ExternalArtwork.create(:title => 'Contemporary Pop') }
      let!(:david_poppie)       { ExternalArtist.create(:full_name => 'David Poppie') }
      let!(:kung_fu_lollipop)   { ExternalArtwork.create(:title => 'Kung-Fu Lollipop') }

      it "prefers the best prefix that matches a given string" do
        ExternalArtwork.fulltext_search('pop').first.should == pop
        ExternalArtwork.fulltext_search('poppie').first.should == david_poppie
        ExternalArtwork.fulltext_search('pop cult').first.should == pop_culture
        ExternalArtwork.fulltext_search('pop', :max_results => 5)[4].should == kung_fu_lollipop
      end

    end
    context "with an index name specified" do
      
      let!(:abc)       { ExternalArtwork.create(:title => "abc") }
      let!(:abcd)      { ExternalArtwork.create(:title => "abcd") }
      let!(:abcde)     { ExternalArtwork.create(:title => "abcde") }
      let!(:abcdef)    { ExternalArtwork.create(:title => "abcdef") }
      let!(:abcdefg)   { ExternalArtwork.create(:title => "abcdefg") }
      let!(:abcdefgh)  { ExternalArtwork.create(:title => "abcdefgh") }
      
      it "returns exact matches from a list of similar prefixes" do
        ExternalArtwork.fulltext_search('abc').first.should == abc
        ExternalArtwork.fulltext_search('abcd').first.should == abcd
        ExternalArtwork.fulltext_search('abcde').first.should == abcde
        ExternalArtwork.fulltext_search('abcdef').first.should == abcdef
        ExternalArtwork.fulltext_search('abcdefg').first.should == abcdefg
        ExternalArtwork.fulltext_search('abcdefgh').first.should == abcdefgh
      end

    end
    
    context "with an index name specified" do

      it "cleans up item from the index after they're destroyed" do
        foobar = ExternalArtwork.create(:title => "foobar")
        barfoo = ExternalArtwork.create(:title => "barfoo")
        ExternalArtwork.fulltext_search('foobar').should == [foobar, barfoo]
        foobar.destroy
        ExternalArtwork.fulltext_search('foobar').should == [barfoo]
        barfoo.destroy
        ExternalArtwork.fulltext_search('foobar').should == []
      end

    end
    
    context "with an index name specified and no fields provided to index" do

      let!(:big_bang) { ExternalArtworkNoFieldsSupplied.create(:title => 'Big Bang', :artist => 'David Poppie', :year => '2009') }

      it "indexes the string returned by to_s" do
        ExternalArtworkNoFieldsSupplied.fulltext_search('big bang').first.should == big_bang
        ExternalArtworkNoFieldsSupplied.fulltext_search('poppie').first.should == big_bang
        ExternalArtworkNoFieldsSupplied.fulltext_search('2009').first.should == big_bang
      end

    end
    
    context "with multiple indexes defined" do
      
      let!(:pop)                { MultiExternalArtwork.create(:title => 'Pop', :year => '1970', :artist => 'Joe Schmoe') }
      let!(:pop_culture)        { MultiExternalArtwork.create(:title => 'Pop Culture', :year => '1977', :artist => 'Jim Schmoe') }
      let!(:contemporary_pop)   { MultiExternalArtwork.create(:title => 'Contemporary Pop', :year => '1800', :artist => 'Bill Schmoe') }
      let!(:kung_fu_lollipop)   { MultiExternalArtwork.create(:title => 'Kung-Fu Lollipop', :year => '2006', :artist => 'Michael Anderson') }
      
      it "allows searches to hit a particular index" do
        title_results = MultiExternalArtwork.fulltext_search('pop', :index => 'mongoid_fulltext.titles').sort_by{ |x| x.title }
        title_results.should == [pop, pop_culture, contemporary_pop, kung_fu_lollipop].sort_by{ |x| x.title }
        year_results = MultiExternalArtwork.fulltext_search('197', :index => 'mongoid_fulltext.years').sort_by{ |x| x.title }
        year_results.should == [pop, pop_culture].sort_by{ |x| x.title }
        all_results = MultiExternalArtwork.fulltext_search('1800 and', :index => 'mongoid_fulltext.all').sort_by{ |x| x.title }
        all_results.should == [contemporary_pop, kung_fu_lollipop].sort_by{ |x| x.title }
      end

      it "should raise an error if you don't specify which index to search with" do
        lambda { MultiExternalArtwork.fulltext_search('foobar') }.should raise_error(Mongoid::FullTextSearch::UnspecifiedIndexError)
      end

    end
    
    context "with multiple fields indexed and the same index used by multiple models" do
      
      let!(:andy_warhol)         { MultiFieldArtist.create(:full_name => 'Andy Warhol', :birth_year => '1928') }
      let!(:warhol)              { MultiFieldArtwork.create(:title => 'Warhol', :year => '2010') }
      let!(:pablo_picasso)       { MultiFieldArtist.create(:full_name => 'Pablo Picasso', :birth_year => '1881') }
      let!(:portrait_of_picasso) { MultiFieldArtwork.create(:title => 'Portrait of Picasso', :year => '1912') }

      it "allows searches across all models on both fields indexed" do
        MultiFieldArtist.fulltext_search('2010').first.should == warhol
        MultiFieldArtist.fulltext_search('andy').first.should == andy_warhol
        MultiFieldArtist.fulltext_search('pablo').first.should == pablo_picasso
        MultiFieldArtist.fulltext_search('1881').first.should == pablo_picasso
        MultiFieldArtist.fulltext_search('portrait 1912').first.should == portrait_of_picasso
        
        MultiFieldArtwork.fulltext_search('2010').first.should == warhol
        MultiFieldArtwork.fulltext_search('andy').first.should == andy_warhol
        MultiFieldArtwork.fulltext_search('pablo').first.should == pablo_picasso
        MultiFieldArtwork.fulltext_search('1881').first.should == pablo_picasso
        MultiFieldArtwork.fulltext_search('portrait 1912').first.should == portrait_of_picasso
      end

    end
    context "with filters applied to multiple models" do
      
      let!(:foobar_artwork)    { FilteredArtwork.create(:title => 'foobar') }
      let!(:barfoo_artwork)    { FilteredArtwork.create(:title => 'barfoo') }
      let!(:foobar_artist)     { FilteredArtist.create(:full_name => 'foobar') }
      let!(:barfoo_artist)     { FilteredArtist.create(:full_name => 'barfoo') }

      it "allows filtered searches" do
        FilteredArtwork.fulltext_search('foobar', :is_artwork => true).should == [foobar_artwork, barfoo_artwork]
        FilteredArtist.fulltext_search('foobar', :is_artwork => true).should == [foobar_artwork, barfoo_artwork]

        FilteredArtwork.fulltext_search('foobar', :is_artwork => true, :is_foobar => true).should == [foobar_artwork]
        FilteredArtwork.fulltext_search('foobar', :is_artwork => true, :is_foobar => false).should == [barfoo_artwork]
        FilteredArtwork.fulltext_search('foobar', :is_artwork => false, :is_foobar => true).should == [foobar_artist]
        FilteredArtwork.fulltext_search('foobar', :is_artwork => false, :is_foobar => false).should == [barfoo_artist]

        FilteredArtist.fulltext_search('foobar', :is_artwork => true, :is_foobar => true).should == [foobar_artwork]
        FilteredArtist.fulltext_search('foobar', :is_artwork => true, :is_foobar => false).should == [barfoo_artwork]
        FilteredArtist.fulltext_search('foobar', :is_artwork => false, :is_foobar => true).should == [foobar_artist]
        FilteredArtist.fulltext_search('foobar', :is_artwork => false, :is_foobar => false).should == [barfoo_artist]
      end

    end

    context "with different filters applied to multiple models" do
      let!(:foo_artwork)    { FilteredArtwork.create(:title => 'foo') }
      let!(:bar_artist)     { FilteredArtist.create(:full_name => 'bar') }
      let!(:baz_other)      { FilteredOther.create(:name => 'baz') }

      # These three models are all indexed by the same mongoid_fulltext index, but have different filters
      # applied. The index created on the mongoid_fulltext collection should include the ngram and score
      # fields as well as the union of all the filter fields to allow for efficient lookups.

      it "creates a proper index for searching efficiently" do
        [ FilteredArtwork, FilteredArtist, FilteredOther].each do |klass|
          klass.create_indexes
        end
        index_collection = FilteredArtwork.collection.database['mongoid_fulltext.artworks_and_artists']
        ngram_indexes = []
        index_collection.indexes.each {|idef| ngram_indexes << idef if idef['key'].has_key?('ngram') }
        ngram_indexes.length.should == 1
        keys = ngram_indexes.first['key'].keys
        expected_keys = ['ngram','score', 'filter_values.is_fuzzy', 'filter_values.is_awesome',
                         'filter_values.is_foobar', 'filter_values.is_artwork', 'filter_values.is_artist', 'filter_values.colors?'].sort
        keys.sort.should == expected_keys
      end

    end
    
    context "with partitions applied to a model" do
      
      let!(:artist_2) { PartitionedArtist.create(:full_name => 'foobar', :exhibitions => [ "Art Basel 2011", "Armory NY" ]) }
      let!(:artist_1) { PartitionedArtist.create(:full_name => 'foobar', :exhibitions => [ "Art Basel 2011", ]) }
      let!(:artist_0) { PartitionedArtist.create(:full_name => 'foobar', :exhibitions => [ ]) }

      it "allows partitioned searches" do
        artists_by_exhibition_length = [ artist_0, artist_1, artist_2 ].sort_by{ |x| x.exhibitions.length }
        PartitionedArtist.fulltext_search('foobar').sort_by{ |x| x.exhibitions.length }.should == artists_by_exhibition_length
        PartitionedArtist.fulltext_search('foobar', :exhibitions => [ "Armory NY" ]).should == [ artist_2 ]
        art_basel_only = PartitionedArtist.fulltext_search('foobar', :exhibitions => [ "Art Basel 2011" ]).sort_by{ |x| x.exhibitions.length }
        art_basel_only.should == [ artist_1, artist_2 ].sort_by{ |x| x.exhibitions.length }
        PartitionedArtist.fulltext_search('foobar', :exhibitions => [ "Art Basel 2011", "Armory NY" ]).should == [ artist_2 ]
      end

    end

    context "using search options" do
      let!(:patterns)    { BasicArtwork.create(:title => 'Flower Patterns') }
      let!(:flowers)     { BasicArtwork.create(:title => 'Flowers') }

      it "returns max_results" do
        BasicArtwork.fulltext_search('flower', { :max_results => 1 }).length.should == 1
      end
      
      it "returns scored results" do
        results = BasicArtwork.fulltext_search('flowers', { :return_scores => true })
        first_result = results[0]
        first_result.is_a?(Array).should be_true
        first_result.size.should == 2
        first_result[0].should == flowers
        first_result[1].is_a?(Float).should be_true
      end
    end

    context "with various word separators" do
      let!(:hard_edged_painting)   { BasicArtwork.create(:title => "Hard-edged painting") }
      let!(:edgy_painting)         { BasicArtwork.create(:title => "Edgy painting") }
      let!(:hard_to_find_ledge)    { BasicArtwork.create(:title => "Hard to find ledge") }

      it "should treat dashes as word separators, giving a score boost to each dash-separated word" do
        BasicArtwork.fulltext_search('hard-edged').first.should == hard_edged_painting
        BasicArtwork.fulltext_search('hard edge').first.should == hard_edged_painting
        BasicArtwork.fulltext_search('hard edged').first.should == hard_edged_painting
      end
    end

    context "returning scores" do
      # Since we return scores, let's make some weak guarantees about what they actually mean
      
      let!(:mao_yan)      { ExternalArtist.create(:full_name => "Mao Yan") }
      let!(:mao)          { ExternalArtwork.create(:title => "Mao by Andy Warhol") }
      let!(:maox)         { ExternalArtwork.create(:title => "Maox by Randy Morehall") }
      let!(:somao)        { ExternalArtwork.create(:title => "Somao by Randy Morehall") }

      it "returns basic matches that don't match a whole word and aren't prefixes with score < 1" do
        ['paox', 'porehall'].each do |query|
          results = ExternalArtist.fulltext_search(query, { :return_scores => true })
          results.length.should > 0
          results.map{ |result| result[-1] }.inject(true){ |accum, item| accum &= (item < 1) }.should be_true
        end
      end
      
      it "returns prefix matches with a score >= 1 but < 2" do
        ['warho', 'rand'].each do |query|
          results = ExternalArtist.fulltext_search(query, { :return_scores => true })
          results.length.should > 0
          results.map{ |result| result[-1] if result[0].to_s.starts_with?(query)}.compact.inject(true){ |accum, item| accum &= (item >= 1 and item < 2) }.should be_true
        end
      end
      
      it "returns full-word matches with a score >= 2" do
        ['andy', 'warhol', 'mao'].each do |query|
          results = ExternalArtist.fulltext_search(query, { :return_scores => true })
          results.length.should > 0
          results.map{ |result| result[-1] if result[0].to_s.split(' ').member?(query) }.compact.inject(true){ |accum, item| accum &= (item >= 2) }.should be_true
        end
      end
      
    end

    context "with stop words defined" do
      let!(:flowers)      { StopwordsArtwork.create(:title => "Flowers by Andy Warhol") }
      let!(:many_ands)    { StopwordsArtwork.create(:title => "Foo and bar and baz and foobar") }
      let!(:harry)        { StopwordsArtwork.create(:title => "Harry in repose by JK Rowling") }

      it "doesn't give a full-word score boost to stopwords" do
        StopwordsArtwork.fulltext_search("andy").map{ |a| a.title }.should == [flowers.title, many_ands.title]
        StopwordsArtwork.fulltext_search("warhol and other stuff").map{ |a| a.title }.should == [flowers.title, many_ands.title]
      end

      it "allows searching on words that are more than one letter, less than the ngram length and not stopwords" do
        StopwordsArtwork.fulltext_search("jk").map{ |a| a.title }.should == [harry.title]
        StopwordsArtwork.fulltext_search("by").map{ |a| a.title }.should == []
      end

    end

    context "indexing short prefixes" do
      let!(:dimethyl_mercury)   { ShortPrefixesArtwork.create(:title => "Dimethyl Mercury by Damien Hirst") }
      let!(:volume)             { ShortPrefixesArtwork.create(:title => "Volume by Dadamaino") }
      let!(:damaged)            { ShortPrefixesArtwork.create(:title => "Damaged: Photographs from the Chicago Daily News 1902-1933 (Governor) by Lisa Oppenheim") }
      let!(:frozen)             { ShortPrefixesArtwork.create(:title => "Frozen Fountain XXX by Evelyn Rosenberg") }
      let!(:skull)              { ShortPrefixesArtwork.create(:title => "Skull by Andy Warhol") }

      it "finds the most relevant items with prefix indexing" do
        ShortPrefixesArtwork.fulltext_search("damien").first.should == dimethyl_mercury
        ShortPrefixesArtwork.fulltext_search("dami").first.should == dimethyl_mercury
        ShortPrefixesArtwork.fulltext_search("dama").first.should == damaged
        ShortPrefixesArtwork.fulltext_search("dam").first.should_not == volume
        ShortPrefixesArtwork.fulltext_search("dadamaino").first.should == volume
        ShortPrefixesArtwork.fulltext_search("kull").first.should == skull
      end

      it "doesn't index prefixes of stopwords" do
        # damaged has the word "from" in it, which shouldn't get indexed.
        ShortPrefixesArtwork.fulltext_search("fro").should == [frozen]
      end

      it "does index prefixes that would be stopwords taken alone" do
        # skull has the word "andy" in it, which should get indexed as "and" even though "and" is a stopword
        ShortPrefixesArtwork.fulltext_search("and").should == [skull]
      end
    end

    context "remove_from_ngram_index" do
      let!(:flowers1)     { BasicArtwork.create(:title => 'Flowers 1') }
      let!(:flowers2)     { BasicArtwork.create(:title => 'Flowers 1') }

      it "removes all records from the index" do
        BasicArtwork.remove_from_ngram_index
        BasicArtwork.fulltext_search('flower').length.should == 0
      end
      
      it "removes a single record from the index" do
        flowers1.remove_from_ngram_index
        BasicArtwork.fulltext_search('flower').length.should == 1
      end
    end
    
    context "update_ngram_index" do
      let!(:flowers1)     { BasicArtwork.create(:title => 'Flowers 1') }
      let!(:flowers2)     { BasicArtwork.create(:title => 'Flowers 2') }

      context "when config[:update_if] exists" do

        let(:painting)          { BasicArtwork.new :title => 'Painting' }
        let(:conditional_index) { BasicArtwork.mongoid_fulltext_config["mongoid_fulltext.index_conditional"] }

        before(:all) do
          BasicArtwork.class_eval do
            fulltext_search_in :title, :index_name => "mongoid_fulltext.index_conditional"
          end
        end

        after(:all) do
          # Moped 1.0.0rc raises an error when removing a collection that does not exist
          # Will be fixed soon.
          begin
            Mongoid.default_session["mongoid_fulltext.index_conditional"].drop
          rescue Moped::Errors::OperationFailure => e
          end
          BasicArtwork.mongoid_fulltext_config.delete "mongoid_fulltext.index_conditional"
        end

        context "and is a symbol" do

          before(:all) do
            conditional_index[:update_if] = :persisted?
          end

          context "when sending the symbol to the document evaluates to false" do

            it "doesn't update the index for the document" do
              painting.update_ngram_index
              BasicArtwork.fulltext_search('painting', :index => "mongoid_fulltext.index_conditional").length.should be 0
            end

          end
        end

        context "and is a string" do

          before(:all) do
            conditional_index[:update_if] = 'false'
          end

          context "when evaluating the string within the document's instance evaluates to false" do

            it "doesn't update the index for the document" do
              painting.update_ngram_index
              BasicArtwork.fulltext_search('painting', :index => "mongoid_fulltext.index_conditional").length.should be 0
            end

          end
        end

        context "and is a proc" do

          before(:all) do
            conditional_index[:update_if] = Proc.new { false }
          end

          context "when evaluating the string within the document's instance evaluates to false" do

            it "doesn't update the index for the document" do
              painting.update_ngram_index
              BasicArtwork.fulltext_search('painting', :index => "mongoid_fulltext.index_conditional").length.should be 0
            end

          end
        end

        context "and is not a symbol, string, or proc" do

          before(:all) do
            conditional_index[:update_if] = %w(this isn't a symbol, string, or proc)
          end

          it "doesn't update the index for the document" do
            painting.update_ngram_index
            BasicArtwork.fulltext_search('painting', :index => "mongoid_fulltext.index_conditional").length.should be 0
          end

        end
      end

      context "from scratch" do

        before(:each) do
          Mongoid.default_session["mongoid_fulltext.index_basicartwork_0"].drop
        end

        it "updates index on a single record" do
          flowers1.update_ngram_index
          BasicArtwork.fulltext_search('flower').length.should == 1
        end
        
        it "updates index on all records" do
          BasicArtwork.update_ngram_index
          BasicArtwork.fulltext_search('flower').length.should == 2
        end

      end
      
      context "incremental" do
      
        it "removes an existing record" do
          coll = Mongoid.default_session["mongoid_fulltext.index_basicartwork_0"]
          coll.find('document_id' => flowers1._id).remove_all
          coll.find('document_id' => flowers1._id).one.should == nil
          flowers1.update_ngram_index
        end
        
      end

      context "mongoid indexes" do
      
        it "can re-create dropped indexes" do
          # there're no indexes by default as Mongoid.autocreate_indexes is set to false
          # but mongo will automatically attempt to index _id in the background
          Mongoid.default_session["mongoid_fulltext.index_basicartwork_0"].indexes.count.should <= 1
          BasicArtwork.create_indexes
          expected_indexes = ['_id_', 'fts_index', 'document_id_1'].sort
          current_indexes = []
          Mongoid.default_session["mongoid_fulltext.index_basicartwork_0"].indexes.each do |idef|
            current_indexes << idef['name']
          end
          current_indexes.sort.should == expected_indexes
        end
        
        it "doesn't fail on models that don't have a fulltext index" do
          lambda { HiddenDragon.create_indexes }.should_not raise_error
        end

        it "doesn't blow up when the Mongoid.logger is set to false" do
          Mongoid.logger = false
          BasicArtwork.create_indexes
        end
        
      end

    end

    context "batched reindexing" do
      let!(:flowers1) { DelayedArtwork.create(:title => 'Flowers 1') }

      it "should not rebuild index until explicitly invoked" do
        DelayedArtwork.fulltext_search("flowers").length.should == 0
        DelayedArtwork.update_ngram_index
        DelayedArtwork.fulltext_search("flowers").length.should == 1
      end
    end

    # For =~ operator documentation
    # https://github.com/dchelimsky/rspec/blob/master/lib/spec/matchers/match_array.rb#L53
    
    context "with artwork that returns an array of colors as a filter" do
      let!(:title) {"title"}
      let!(:nomatch) {"nomatch"}
      let!(:red) {"red"}
      let!(:green) {"green"}
      let!(:blue) {"blue"}
      let!(:yellow) {"yellow"}
      let!(:brown) {"brown"}

      let!(:rgb_artwork) {FilteredArtwork.create(:title => "#{title} rgb", :colors => [red,green,blue])}
      let!(:holiday_artwork) {FilteredArtwork.create(:title => "#{title} holiday", :colors => [red,green])}
      let!(:aqua_artwork) {FilteredArtwork.create(:title => "#{title} aqua", :colors => [green,blue])}

      context "with a fulltext search passing red, green, and blue to the colors filter" do
        it "should return the rgb artwork" do
          FilteredArtwork.fulltext_search(title, :colors? => [red,green,blue]).should == [rgb_artwork]
        end
      end

      context "with a fulltext search passing blue and red to the colors filter" do
        it "should return the rgb artwork" do
          FilteredArtwork.fulltext_search(title, :colors? => [blue,red]).should == [rgb_artwork]
        end
      end

      context "with a fulltext search passing green to the colors filter" do
        it "should return all artwork" do
          FilteredArtwork.fulltext_search(title, :colors? => [green]).should =~ [rgb_artwork,holiday_artwork,aqua_artwork]
        end
      end

      context "with a fulltext search passing no colors to the filter" do
        it "should return all artwork" do
          FilteredArtwork.fulltext_search(title).should =~ [rgb_artwork,holiday_artwork,aqua_artwork]
        end
      end

      context "with a fulltext search passing green and yellow to the colors filter" do
        it "should return no artwork" do
          FilteredArtwork.fulltext_search(title, :colors? => [green,yellow]).should == []
        end
      end

      context "with the query operator overridden to use $in instead of the default $all" do
        context "with a fulltext search passing green and yellow to the colors filter" do
          it "should return all of the artwork" do
            FilteredArtwork.fulltext_search(title, :colors? => {:any => [green,yellow]}).should =~ [rgb_artwork,holiday_artwork,aqua_artwork]
          end
        end

        context "with a fulltext search passing brown and yellow to the colors filter" do
          it "should return none of the artwork" do
            FilteredArtwork.fulltext_search(title, :colors? => {:any => [brown,yellow]}).should == []
          end
        end

        context "with a fulltext search passing blue to the colors filter" do
          it "should return the rgb and aqua artwork" do
            FilteredArtwork.fulltext_search(title, :colors? => {:any => [blue]}).should == [rgb_artwork,aqua_artwork]
          end
        end

        context "with a fulltext search term that won't match" do
          it "should return none of the artwork" do
            FilteredArtwork.fulltext_search(nomatch, :colors? => {:any => [green,yellow]}).should == []
          end
        end
      end

      context "with the query operator overridden to use $all" do
        context "with a fulltext search passing red, green, and blue to the colors filter" do
          it "should return the rgb artwork" do
            FilteredArtwork.fulltext_search(title, :colors? => {:all => [red,green,blue]}).should == [rgb_artwork]
          end
        end

        context "with a fulltext search passing green to the colors filter" do
          it "should return all artwork" do
            FilteredArtwork.fulltext_search(title, :colors? => {:all => [green]}).should =~ [rgb_artwork,holiday_artwork,aqua_artwork]
          end
        end
      end

      context "with an unknown query operator used to override the default $all" do
        context "with a fulltext search passing red, green, and blue to the colors filter" do
          it "should raise an error" do
            lambda {
              FilteredArtwork.fulltext_search(title, :colors? => {:unknown => [red,green,blue]})
            }.should raise_error(Mongoid::FullTextSearch::UnknownFilterQueryOperator)
          end
        end
      end

      context "should properly work with non-latin strings (i.e. cyrillic)" do
        let!(:morning) { RussianArtwork.create(:title => "Утро в сосновом лесу Шишкин Morning in a Pine Forest Shishkin") }

        it "should find a match if query is non-latin string" do
          # RussianArtwork is just like BasicArtwork, except that we set :alphabet to
          # 'abcdefghijklmnopqrstuvwxyz0123456789абвгдежзиклмнопрстуфхцчшщъыьэюя'
          RussianArtwork.fulltext_search("shishkin").first.should == morning
          RussianArtwork.fulltext_search("шишкин").first.should == morning
        end

      end
    end

  end
end
