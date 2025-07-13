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
  spec.required_ruby_version = ">= 3.0.0"

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
  spec.add_dependency "ruby_llm", "~> 1.3"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "pdf-reader", "~> 2.0"
  spec.add_dependency "docx", "~> 0.8"
  spec.add_dependency "activerecord", "~> 7.0"
  spec.add_dependency "activestorage", "~> 7.0"
  spec.add_dependency "sqlite3", "~> 1.4"
  
  # Search dependencies
  spec.add_dependency "neighbor", "~> 0.3" # Vector similarity search
  spec.add_dependency "searchkick", "~> 5.0" # Full-text search
  spec.add_dependency "sqlite-vec", "~> 0.1" # SQLite vector extension

  # Development dependencies
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "simplecov", "~> 0.21"
  spec.add_development_dependency "undercover", "~> 0.7"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "annotate", "~> 3.2"
end