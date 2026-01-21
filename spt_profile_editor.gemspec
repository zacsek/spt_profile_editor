# frozen_string_literal: true

require_relative "lib/spt_profile_editor/version"

Gem::Specification.new do |spec|
  spec.name = "spt_profile_editor"
  spec.version = SptProfileEditor::VERSION
  spec.authors = ["Zoltán Szőcs"]
  spec.email = ["zacsek@gmail.com"]

  spec.summary = "A Ruby library for reading and editing SPT-AKI profiles."
  spec.description = "A Ruby library for reading and editing SPT-AKI profiles. Allows for programmatic modification of player profiles for SPT-AKI."
  spec.homepage = "https://github.com/gemini-testing/spt_profile_editor"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) || f.start_with?(*%w[Gemfile .gitignore .rspec spec/ .rubocop.yml])
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Register a new dependency of your gem
  spec.add_dependency "json"
  spec.add_development_dependency "rspec", "~> 3.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
