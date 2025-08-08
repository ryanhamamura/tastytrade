# frozen_string_literal: true

require_relative "lib/tastytrade/version"

Gem::Specification.new do |spec|
  spec.name = "tastytrade"
  spec.version = Tastytrade::VERSION
  spec.authors = ["Ryan Hamamura"]
  spec.email = ["58859899+ryanhamamura@users.noreply.github.com"]

  spec.summary = "Unofficial Ruby SDK for the Tastytrade API"
  spec.description = "An unofficial Ruby SDK for accessing the Tastytrade API. " \
                     "This gem is not affiliated with, endorsed by, or sponsored by " \
                     "Tastytrade or Tastyworks. Use at your own risk."
  spec.homepage = "https://github.com/ryanhamamura/tastytrade"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ryanhamamura/tastytrade"
  spec.metadata["changelog_uri"] = "https://github.com/ryanhamamura/tastytrade/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/tastytrade"
  spec.metadata["bug_tracker_uri"] = "https://github.com/ryanhamamura/tastytrade/issues"
  spec.metadata["rubygems_mfa_required"] = "false"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.12"
  spec.add_dependency "faraday-retry", "~> 2.2"
  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-table", "~> 0.12"

  # Development dependencies
  spec.add_development_dependency "bundler-audit", "~> 0.9"
  spec.add_development_dependency "dotenv", "~> 3.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.68"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.3"
  spec.add_development_dependency "webmock", "~> 3.24"
  spec.add_development_dependency "yard", "~> 0.9"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
