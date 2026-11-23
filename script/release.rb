require 'ruby-gem-release/changelog'
require 'ruby-gem-release/workflow/ruby_gem'

# Builds the ruby-gem-release workflow used by the Rakefile, the Release GitHub Actions workflow, and spec/release.
module MongoidFulltextRelease
  def self.workflow(**options)
    RubyGemRelease::Workflow::RubyGem.new(
      version: RubyGemRelease::Version::RubyConstant.new(path: 'lib/mongoid/full_text_search/version.rb', constant: 'VERSION'),
      changelog: RubyGemRelease::Changelog::Intridea.new(placeholder: '* Your contribution here.'),
      **options
    )
  end
end
