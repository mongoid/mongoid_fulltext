
require 'spec_helper'

describe Mongoid::FullTextSearch do
  context 'Localized fields' do
    let!(:my_doc) { MyLocalizedDoc.create!(title_translations: { en: 'Title', cs: 'Nazev' }) }

    before(:each) do
      @default_locale = ::I18n.locale
      ::I18n.locale = locale
    end

    after(:each) do
      ::I18n.locale = @default_locale
    end

    context 'en' do
      let(:locale) { :en }
      it { expect(MyLocalizedDoc.fulltext_search('title')).to include my_doc }
      it { expect(MyLocalizedDoc.fulltext_search('nazev')).not_to include my_doc }
    end

    context 'cs' do
      let(:locale) { :cs }
      it { expect(MyLocalizedDoc.fulltext_search('title')).not_to include my_doc }
      it { expect(MyLocalizedDoc.fulltext_search('nazev')).to include my_doc }
    end
  end
end
