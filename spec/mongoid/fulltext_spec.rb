require 'spec_helper'

module Mongoid
  describe FullTextSearch do
    context "with default settings" do
      
      let!(:flower_myth) { BasicArtwork.create(:title => 'Flower Myth') }
      let!(:flowers)     { BasicArtwork.create(:title => 'Flowers') }
      let!(:lowered)     { BasicArtwork.create(:title => 'Lowered') }
      let!(:cookies)     { BasicArtwork.create(:title => 'Cookies') }
      
      it "returns exact matches" do
        BasicArtwork.fulltext_search('Flower Myth', 1).first.should == flower_myth
        BasicArtwork.fulltext_search('Flowers', 1).first.should == flowers
        BasicArtwork.fulltext_search('Cookies', 1).first.should == cookies
        BasicArtwork.fulltext_search('Lowered', 1).first.should == lowered
      end

      it "returns exact matches regardless of case" do
        BasicArtwork.fulltext_search('fLOWER mYTH', 1).first.should == flower_myth
        BasicArtwork.fulltext_search('FLOWERS', 1).first.should == flowers
        BasicArtwork.fulltext_search('cOOkies', 1).first.should == cookies
        BasicArtwork.fulltext_search('lOWERED', 1).first.should == lowered
      end

      it "returns all relevant results, sorted by relevance" do
        BasicArtwork.fulltext_search('Flowers').should == [flowers, flower_myth, lowered]
      end

      it "prefers prefix matches" do
        BasicArtwork.fulltext_search('Flowered').first.should == flowers
        BasicArtwork.fulltext_search('Lowers').first.should == lowered
        BasicArtwork.fulltext_search('Cookieflowers').first.should == cookies
      end

    end
  end
end
