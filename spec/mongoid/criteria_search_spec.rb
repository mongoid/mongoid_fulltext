
require 'spec_helper'

describe Mongoid::FullTextSearch do
  context 'Criteria' do
    let!(:my_doc_1) { MyDoc.create!(title: 'My Doc 1') }
    let!(:my_doc_2) { MyDoc.create!(title: 'My Doc 2', value: 10) }

    let(:result) { MyDoc.where(value: 10).fulltext_search('doc') }

    it { expect(result).not_to include my_doc_1 }
    it { expect(result).to include my_doc_2 }
  end
end
