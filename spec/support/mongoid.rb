module Mongoid
  def self.default_session
    default_client
  end
end if Mongoid::Compatibility::Version.mongoid5? || Mongoid::Compatibility::Version.mongoid6?
