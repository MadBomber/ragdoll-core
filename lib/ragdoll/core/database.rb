# frozen_string_literal: true

require 'active_record'
require 'logger'

module Ragdoll
  module Core
    class Database
      def self.setup(config = {})
        database_config = default_config.merge(config)
        
        # Set up ActiveRecord connection
        ActiveRecord::Base.establish_connection(database_config)
        
        # Set up logging if specified
        if database_config[:logger]
          ActiveRecord::Base.logger = database_config[:logger]
        end
        
        # Auto-migrate if specified
        if database_config[:auto_migrate]
          migrate!
        end
      end
      
      def self.migrate!
        # Get the path to the gem root directory  
        # Current file is lib/ragdoll/core/database.rb, so go up 3 levels to get to gem root
        gem_root = File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..'))
        migration_paths = [
          File.join(gem_root, 'db', 'migrate')
        ]
        
        ActiveRecord::Migration.verbose = true
        
        # Ensure schema_migrations table exists first
        unless ActiveRecord::Base.connection.table_exists?('schema_migrations')
          ActiveRecord::Base.connection.create_table('schema_migrations', id: false) do |t|
            t.string :version, null: false
          end
          ActiveRecord::Base.connection.add_index('schema_migrations', :version, unique: true)
        end
        
        # Debug migration path (silenced for clean test output)
        # puts "Migration path: #{migration_paths.first}" if ActiveRecord::Migration.verbose
        migration_files = Dir[File.join(migration_paths.first, '*.rb')].sort
        # puts "Found #{migration_files.length} migration files" if ActiveRecord::Migration.verbose
        
        # Load and run each migration manually since ActiveRecord migration context seems broken
        migration_files.each do |migration_file|
          # Extract version from filename
          version = File.basename(migration_file, '.rb').split('_').first
          
          # Skip if already migrated
          next if ActiveRecord::Base.connection.select_values(
            "SELECT version FROM schema_migrations WHERE version = '#{version}'"
          ).any?
          
          # Load the migration file to define the class
          require migration_file
          
          # Get the migration class - convert snake_case to CamelCase
          filename_parts = File.basename(migration_file, '.rb').split('_')[1..-1]
          migration_class_name = filename_parts.map { |part| part.capitalize }.join
          
          begin
            migration_class = Object.const_get(migration_class_name)
          rescue NameError
            puts "Warning: Could not find migration class #{migration_class_name} in #{migration_file}"
            next
          end
          
          # Run the migration quietly
          old_verbose = ActiveRecord::Migration.verbose
          ActiveRecord::Migration.verbose = false
          migration_class.migrate(:up)
          ActiveRecord::Migration.verbose = old_verbose
          
          # Record the migration
          ActiveRecord::Base.connection.insert(
            "INSERT INTO schema_migrations (version) VALUES ('#{version}')"
          )
          
          # Silenced migration progress - uncomment for debugging
          # puts "Migrated #{migration_class_name}" if ActiveRecord::Migration.verbose
        end
      end
      
      def self.reset!
        ActiveRecord::Migration.verbose = false
        
        # Drop all tables if they exist
        %w[ragdoll_embeddings ragdoll_documents schema_migrations].each do |table|
          ActiveRecord::Base.connection.drop_table(table) if ActiveRecord::Base.connection.table_exists?(table)
        end
        
        migrate!
      end
      
      def self.connected?
        ActiveRecord::Base.connected?
      end
      
      def self.disconnect!
        ActiveRecord::Base.clear_all_connections!
      end
      
      private
      
      def self.default_config
        {
          adapter: 'sqlite3',
          database: File.join(Dir.home, '.ragdoll', 'ragdoll.sqlite3'),
          timeout: 5000,
          auto_migrate: true,
          logger: Logger.new(STDOUT, level: Logger::WARN)
        }
      end
      
      def self.migration_paths
        [File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'db', 'migrate')]
      end
    end
  end
end