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
        migration_paths = [
          File.join(File.dirname(__FILE__), '..', '..', '..', '..', 'db', 'migrate')
        ]
        
        ActiveRecord::Migration.verbose = true
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).migrate
      end
      
      def self.reset!
        ActiveRecord::Migration.verbose = false
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).down(0)
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