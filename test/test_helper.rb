require 'simplecov'

SimpleCov.start do
  add_filter '/test/'
  track_files 'lib/**/*.rb'
  minimum_coverage 0 # Temporarily disable coverage requirement

  add_group 'Core', 'lib/ragdoll/core'
  add_group 'Models', 'lib/ragdoll/core/models'
end

# Load undercover after SimpleCov to avoid circular requires
# Only load in specific test environments to avoid conflicts
if ENV['COVERAGE_UNDERCOVER'] == 'true'
  begin
    require 'undercover'
  rescue LoadError, StandardError => e
    # Undercover is optional - skip if not available or has conflicts
    puts "Skipping undercover due to: #{e.message}" if ENV['DEBUG']
  end
end

require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/ragdoll-core'

# Silence migration output during tests
ActiveRecord::Migration.verbose = false

class Minitest::Test
  def setup
    Ragdoll::Core.reset_configuration!

    # Silence all ActiveRecord output
    ActiveRecord::Base.logger = nil
    ActiveRecord::Migration.verbose = false

    # Setup test database
    Ragdoll::Core::Database.setup({
                                    adapter: 'sqlite3',
                                    database: ':memory:',
                                    timeout: 5000,
                                    auto_migrate: true,
                                    logger: nil
                                  })
  end


  def teardown
    # Clean up database
    if ActiveRecord::Base.connected?
      # Only delete if tables exist
      if ActiveRecord::Base.connection.table_exists?('ragdoll_embeddings')
        Ragdoll::Core::Models::Embedding.delete_all
      end
      if ActiveRecord::Base.connection.table_exists?('ragdoll_documents')
        Ragdoll::Core::Models::Document.delete_all
      end
    end

    Ragdoll::Core.reset_configuration!
  end
end
