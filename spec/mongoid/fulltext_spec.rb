require 'spec_helper'

module Mongoid
  describe FullTextSearch do
    context "with default settings" do
      
      let!(:flower_myth) { BasicArtwork.create(:title => 'Flower Myth') }
      let!(:flowers)     { BasicArtwork.create(:title => 'Flowers') }
      let!(:lowered)     { BasicArtwork.create(:title => 'Lowered') }
      let!(:cookies)     { BasicArtwork.create(:title => 'Cookies') }

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

      let!(:yellow)             { BasicArtwork.create(:title => 'Yellow') }
      let!(:yellow_leaves_2)    { BasicArtwork.create(:title => 'Yellow Leaves 2') }
      let!(:yellow_leaves_3)    { BasicArtwork.create(:title => 'Yellow Leaves 3') }
      let!(:yellow_leaves_20)   { BasicArtwork.create(:title => 'Yellow Leaves 20') }
      let!(:yellow_cup)         { BasicArtwork.create(:title => 'Yellow Cup') }

      it "prefers the best prefix that matches a given string" do
        BasicArtwork.fulltext_search('yellow').first.should == yellow
        BasicArtwork.fulltext_search('yellow leaves', :max_results => 3).sort_by!{ |x| x.title }.should == \
          [yellow_leaves_2, yellow_leaves_3, yellow_leaves_20].sort_by!{ |x| x.title }
        BasicArtwork.fulltext_search('yellow cup').first.should == yellow_cup
      end

    end
    context "with a basic external index" do
      let!(:pablo_picasso)       { ExternalArtist.create(:full_name => 'Pablo Picasso') }
      let!(:portrait_of_picasso) { ExternalArtwork.create(:title => 'Portrait of Picasso') }
      let!(:andy_warhol)         { ExternalArtist.create(:full_name => 'Andy Warhol') }
      let!(:warhol)              { ExternalArtwork.create(:title => 'Warhol') }

      it "returns results of different types from the same query" do
        results = ExternalArtwork.fulltext_search('picasso', :max_results => 2).map{ |result| result }
        results.member?(portrait_of_picasso).should be_true
        results.member?(pablo_picasso).should be_true
        results = ExternalArtist.fulltext_search('picasso', :max_results => 2).map{ |result| result }
        results.member?(portrait_of_picasso).should be_true
        results.member?(pablo_picasso).should be_true
      end

      it "allows use of only the internal index" do
        results = ExternalArtwork.fulltext_search('picasso', :max_results => 1, :use_internal_index => true).map { |result| result }
        results.should == [portrait_of_picasso]
        results = ExternalArtist.fulltext_search('picasso', :max_results => 1,  :use_internal_index => true).map { |result| result }
        results.should == [pablo_picasso]
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

      it "returns results for a single model when passed the :use_internal_index flag" do
        ExternalArtist.fulltext_search('picasso warhol', :use_internal_index => true).should == [pablo_picasso, andy_warhol]
        ExternalArtwork.fulltext_search('picasso warhol', :use_internal_index => true).should == [warhol, portrait_of_picasso]
      end
      
    end
    context "with a basic external index" do

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
  end
end
