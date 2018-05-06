require 'mongoid'
require 'mongoid/compatibility'

require 'mongoid/full_text_search'

require 'unicode_utils'
require 'cgi'

module Mongoid
  module CreateIndexesPatch
    def create_indexes
      create_fulltext_indexes if respond_to?(:create_fulltext_indexes)
      super
    end
  end
end

if Mongoid::Compatibility::Version.mongoid3?
  Mongoid::Indexes::ClassMethods.send(:prepend, Mongoid::CreateIndexesPatch)
else
  Mongoid::Indexable::ClassMethods.send(:prepend, Mongoid::CreateIndexesPatch)
end
