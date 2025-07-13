# frozen_string_literal: true

require_relative "lib/ragdoll/core/version"

Gem::Specification.new do |spec|
  spec.name = "ragdoll-core"
  spec.version = Ragdoll::Core::VERSION
  spec.authors = ["MadBomber"]
  spec.email = ["dewayne@vanhoozer.me"]

  spec.summary = "Core RAG functionality for document processing and semantic search"
  spec.description = "Framework-agnostic RAG (Retrieval-Augmented Generation) library providing document processing, text chunking, embedding generation, and semantic search capabilities"
  spec.homepage = "https://github.com/MadBomber/ragdoll-core"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MadBomber/ragdoll-core"
  spec.metadata["changelog_uri"] = "https://github.com/MadBomber/ragdoll-core/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Core dependencies
  spec.add_dependency "ruby_llm"
  spec.add_dependency "pdf-reader"
  spec.add_dependency "docx"
  spec.add_dependency "activerecord"
  spec.add_dependency "activestorage"

  # Search dependencies
  spec.add_dependency "neighbor"
  spec.add_dependency "searchkick"
  spec.add_dependency "opensearch-ruby"

  # Development dependencies
  spec.add_development_dependency "sqlite3"
  spec.add_development_dependency "sqlite-vec"
  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "undercover"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "annotate"
end
