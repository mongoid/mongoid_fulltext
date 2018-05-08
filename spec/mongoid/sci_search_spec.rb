
require 'spec_helper'

describe Mongoid::FullTextSearch do
  context 'SCI' do
    let!(:my_doc) { MyDoc.create!(title: 'My Doc') }
    let!(:my_inherited_doc) { MyInheritedDoc.create!(title: 'My Inherited Doc') }
    let!(:my_further_inherited_doc) { MyFurtherInheritedDoc.create!(title: 'My Inherited Doc') }

    context 'root class returns results for subclasses' do
      let(:result) { MyDoc.fulltext_search('doc') }
      it { expect(result).to include my_doc }
      it { expect(result).to include my_inherited_doc }
      it { expect(result).to include my_further_inherited_doc }
    end

    context 'child class does not return superclass' do
      let(:result) { MyInheritedDoc.fulltext_search('doc') }
      it { expect(result).not_to include my_doc }
      it { expect(result).to include my_inherited_doc }
      it { expect(result).to include my_further_inherited_doc }
    end

    context 'child class does not return superclass' do
      let(:result) { MyFurtherInheritedDoc.fulltext_search('doc') }
      it { expect(result).not_to include my_doc }
      it { expect(result).not_to include my_inherited_doc }
      it { expect(result).to include my_further_inherited_doc }
    end
  end
end
