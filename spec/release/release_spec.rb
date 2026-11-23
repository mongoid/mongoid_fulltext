if RUBY_ENGINE == 'ruby' && Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.3')
  require_relative '../../script/release'
  require 'ruby-gem-release/rspec'

  RSpec.describe MongoidFulltextRelease do
    include RubyGemRelease::RSpec

    def with_mongoid_fulltext_project
      with_release_project do |project|
        project.copy_files(path: File.expand_path('../..', __dir__), files: %w[
                             script/release.rb mongoid_fulltext.gemspec lib/**/*.rb
                             README.md CHANGELOG.md LICENSE UPGRADING.md
                           ])
        project.configure_workflow(require: 'script/release', builder: 'MongoidFulltextRelease.workflow')
        yield project
      end
    end

    def write_changelog(project, notes)
      project.write('CHANGELOG.md', [
        '### 1.2.0 (Next)', '', notes, '* Your contribution here.', '',
        '### 1.1.0 (2026/01/01)', '', '* Previous release.', ''
      ].join("\n"))
      project.write('lib/mongoid/full_text_search/version.rb', [
        'module Mongoid', '  module FullTextSearch', "    VERSION = '1.2.0'.freeze", '  end', 'end', ''
      ].join("\n"))
      project.commit!
    end

    it 'dates the release and prepares the next patch version' do
      with_mongoid_fulltext_project do |project|
        write_changelog(project, '* [#1](https://github.com/mongoid/mongoid_fulltext/pull/1): Added a feature - [@dblock](https://github.com/dblock).')

        project.release!

        released = project.remote_file('v1.2.0', 'CHANGELOG.md')
        expect(released).to match(%r{\A### 1\.2\.0 \(\d{4}/\d{2}/\d{2}\)\n\n\* \[#1\]})
        expect(released).not_to include('(Next)', 'Your contribution here.')
        expect(project.remote_file('v1.2.0', 'lib/mongoid/full_text_search/version.rb')).to include("VERSION = '1.2.0'")

        pending = project.remote_file('master', 'CHANGELOG.md')
        expect(pending).to start_with("### 1.2.1 (Next)\n\n* Your contribution here.\n\n### 1.2.0 (")
        expect(project.remote_file('master', 'lib/mongoid/full_text_search/version.rb')).to include("VERSION = '1.2.1'")
        expect(project.git('status', '--porcelain')).to be_empty
      end
    end

    it 'rejects placeholder-only notes without changing files or remote refs' do
      with_mongoid_fulltext_project do |project|
        write_changelog(project, '')
        original = project.git('rev-parse', 'origin/master')
        project.run_task('release:workflow:capture')

        expect { project.run_task('release:validate') }.to raise_error(RuntimeError, /no pending changelog notes/)
        expect(project.git('status', '--porcelain')).to be_empty
        expect(project.git('rev-parse', 'origin/master')).to eq(original)
      end
    end
  end
end
