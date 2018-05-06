module Mongoid
  module FullTextSearch
    module Config
      extend ActiveSupport::Concern

      included do
        cattr_accessor :mongoid_fulltext_config
      end
    end
  end
end
