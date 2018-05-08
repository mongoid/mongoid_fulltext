if Mongoid::Compatibility::Version.mongoid5_or_newer?
  module Mongoid
    def self.default_session
      default_client
    end
  end
end
