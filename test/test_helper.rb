require 'simplecov'
require 'undercover'

SimpleCov.start do
  add_filter "/test/"
  track_files "lib/**/*.rb"
  minimum_coverage 70
  
  add_group "Core", "lib/ragdoll/core"
  add_group "Models", "lib/ragdoll/core/models"
end

require 'minitest/autorun'
require 'minitest/pride'
require_relative '../lib/ragdoll-core'

class Minitest::Test
  def setup
    Ragdoll::Core.reset_configuration!
    
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
      Ragdoll::Core::Models::Embedding.delete_all
      Ragdoll::Core::Models::Document.delete_all
    end
    
    Ragdoll::Core.reset_configuration!
  end
end