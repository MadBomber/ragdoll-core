# frozen_string_literal: true

require 'rake'

namespace :db do
  desc "Create the database"
  task :create do
    require_relative '../ragdoll-core'
    
    config = Ragdoll::Core.configuration
    puts "Creating database with config: #{config.database_config.inspect}"
    
    case config.database_config[:adapter]
    when 'sqlite3'
      database_path = config.database_config[:database]
      if database_path != ':memory:'
        FileUtils.mkdir_p(File.dirname(database_path))
        puts "SQLite database path: #{database_path}"
      end
    when 'postgresql'
      # For PostgreSQL, we'd typically create the database here
      puts "PostgreSQL database creation - ensure the database exists on your server"
    when 'mysql2'
      # For MySQL, we'd typically create the database here  
      puts "MySQL database creation - ensure the database exists on your server"
    end
    
    puts "Database creation completed"
  end

  desc "Drop the database"
  task :drop do
    require_relative '../ragdoll-core'
    
    config = Ragdoll::Core.configuration
    puts "Dropping database with config: #{config.database_config.inspect}"
    
    case config.database_config[:adapter]
    when 'sqlite3'
      database_path = config.database_config[:database]
      if database_path != ':memory:' && File.exist?(database_path)
        File.delete(database_path)
        puts "Deleted SQLite database: #{database_path}"
      else
        puts "SQLite database does not exist or is in-memory"
      end
    when 'postgresql', 'mysql2'
      puts "For #{config.database_config[:adapter]}, please drop the database manually on your server"
    end
    
    puts "Database drop completed"
  end

  desc "Setup the database (create and migrate)"
  task :setup => [:create, :migrate]

  desc "Reset the database (drop, create, and migrate)"
  task :reset => [:drop, :create, :migrate]

  desc "Run pending migrations"
  task :migrate do
    require_relative '../ragdoll-core'
    
    puts "Running migrations..."
    Ragdoll::Core::Database.setup({
      auto_migrate: false
    })
    
    Ragdoll::Core::Database.migrate!
    puts "Migrations completed"
  end

  desc "Rollback the database by one migration"
  task :rollback do
    require_relative '../ragdoll-core'
    
    puts "Rolling back migrations..."
    # For now, we'll implement a simple reset since our manual migration doesn't support rollback
    puts "Note: Rollback not yet implemented, use db:reset to start over"
  end

  desc "Show migration status"
  task :migrate_status do
    require_relative '../ragdoll-core'
    
    Ragdoll::Core::Database.setup({
      auto_migrate: false
    })
    
    puts "\nMigration Status:"
    puts "=================="
    
    # Get migration files
    migration_paths = [File.join(File.dirname(__FILE__), '..', '..', 'db', 'migrate')]
    migration_files = Dir[File.join(migration_paths.first, '*.rb')].sort
    
    # Get applied migrations
    applied_versions = []
    if ActiveRecord::Base.connection.table_exists?('schema_migrations')
      applied_versions = ActiveRecord::Base.connection.select_values(
        "SELECT version FROM schema_migrations ORDER BY version"
      )
    end
    
    puts sprintf("%-8s %-20s %s", "Status", "Migration ID", "Migration Name")
    puts "-" * 60
    
    migration_files.each do |migration_file|
      version = File.basename(migration_file, '.rb').split('_').first
      name = File.basename(migration_file, '.rb').split('_')[1..-1].join('_')
      status = applied_versions.include?(version) ? "up" : "down"
      
      puts sprintf("%-8s %-20s %s", status, version, name)
    end
    
    puts "\nTotal migrations: #{migration_files.length}"
    puts "Applied migrations: #{applied_versions.length}"
    puts "Pending migrations: #{migration_files.length - applied_versions.length}"
  end

  desc "Show database schema information"
  task :schema do
    require_relative '../ragdoll-core'
    
    Ragdoll::Core::Database.setup({
      auto_migrate: false
    })
    
    puts "\nDatabase Schema:"
    puts "================"
    puts "Adapter: #{ActiveRecord::Base.connection.adapter_name}"
    
    if ActiveRecord::Base.connection.tables.any?
      ActiveRecord::Base.connection.tables.sort.each do |table|
        puts "\nTable: #{table}"
        columns = ActiveRecord::Base.connection.columns(table)
        columns.each do |column|
          puts "  #{column.name}: #{column.type} (#{column.sql_type})#{' NOT NULL' unless column.null}#{' DEFAULT ' + column.default.inspect if column.default}"
        end
        
        # Show indexes
        indexes = ActiveRecord::Base.connection.indexes(table)
        if indexes.any?
          puts "  Indexes:"
          indexes.each do |index|
            unique_text = index.unique? ? " (unique)" : ""
            puts "    #{index.name}: [#{index.columns.join(', ')}]#{unique_text}"
          end
        end
      end
    else
      puts "No tables found. Run 'rake db:migrate' to create tables."
    end
  end

  desc "Open database console"
  task :console do
    require_relative '../ragdoll-core'
    
    config = Ragdoll::Core.configuration
    
    case config.database_config[:adapter]
    when 'sqlite3'
      database_path = config.database_config[:database]
      if database_path == ':memory:'
        puts "Cannot open console for in-memory database"
      else
        puts "Opening SQLite console for: #{database_path}"
        system("sqlite3", database_path)
      end
    when 'postgresql'
      db_config = config.database_config
      psql_cmd = "psql"
      psql_cmd += " -h #{db_config[:host]}" if db_config[:host]
      psql_cmd += " -p #{db_config[:port]}" if db_config[:port]
      psql_cmd += " -U #{db_config[:username]}" if db_config[:username]
      psql_cmd += " #{db_config[:database]}"
      puts "Opening PostgreSQL console..."
      system(psql_cmd)
    when 'mysql2'
      db_config = config.database_config
      mysql_cmd = "mysql"
      mysql_cmd += " -h #{db_config[:host]}" if db_config[:host]
      mysql_cmd += " -P #{db_config[:port]}" if db_config[:port]
      mysql_cmd += " -u #{db_config[:username]}" if db_config[:username]
      mysql_cmd += " -p" if db_config[:password]
      mysql_cmd += " #{db_config[:database]}"
      puts "Opening MySQL console..."
      system(mysql_cmd)
    else
      puts "Console not supported for adapter: #{config.database_config[:adapter]}"
    end
  end

  desc "Show database statistics"
  task :stats do
    require_relative '../ragdoll-core'
    
    Ragdoll::Core::Database.setup({
      auto_migrate: false
    })
    
    puts "\nDatabase Statistics:"
    puts "==================="
    
    if ActiveRecord::Base.connection.table_exists?('ragdoll_documents')
      doc_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM ragdoll_documents")
      puts "Documents: #{doc_count}"
      
      if doc_count > 0
        doc_types = ActiveRecord::Base.connection.select_rows(
          "SELECT document_type, COUNT(*) FROM ragdoll_documents GROUP BY document_type"
        )
        puts "Document types:"
        doc_types.each { |type, count| puts "  #{type}: #{count}" }
        
        statuses = ActiveRecord::Base.connection.select_rows(
          "SELECT status, COUNT(*) FROM ragdoll_documents GROUP BY status"
        )
        puts "Document statuses:"
        statuses.each { |status, count| puts "  #{status}: #{count}" }
      end
    else
      puts "Documents table does not exist"
    end
    
    if ActiveRecord::Base.connection.table_exists?('ragdoll_embeddings')
      embedding_count = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM ragdoll_embeddings")
      puts "Embeddings: #{embedding_count}"
      
      if embedding_count > 0
        models = ActiveRecord::Base.connection.select_rows(
          "SELECT model_name, COUNT(*) FROM ragdoll_embeddings GROUP BY model_name"
        )
        puts "Embedding models:"
        models.each { |model, count| puts "  #{model}: #{count}" }
        
        usage_stats = ActiveRecord::Base.connection.select_one(
          "SELECT AVG(usage_count) as avg_usage, MAX(usage_count) as max_usage FROM ragdoll_embeddings"
        )
        puts "Usage statistics:"
        puts "  Average usage: #{usage_stats['avg_usage'].to_f.round(2)}"
        puts "  Max usage: #{usage_stats['max_usage']}"
      end
    else
      puts "Embeddings table does not exist"
    end
  end

  desc "Truncate all tables (remove all data but keep structure)"
  task :truncate do
    require_relative '../ragdoll-core'
    
    Ragdoll::Core::Database.setup({
      auto_migrate: false
    })
    
    puts "Truncating all tables..."
    
    # Disable foreign key checks temporarily
    case ActiveRecord::Base.connection.adapter_name.downcase
    when 'sqlite'
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")
    when 'postgresql'
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'replica'")
    when 'mysql'
      ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 0")
    end
    
    # Truncate tables in correct order (dependent tables first)
    %w[ragdoll_embeddings ragdoll_documents].each do |table|
      if ActiveRecord::Base.connection.table_exists?(table)
        ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
        puts "Truncated #{table}"
      end
    end
    
    # Re-enable foreign key checks
    case ActiveRecord::Base.connection.adapter_name.downcase
    when 'sqlite'
      ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    when 'postgresql'
      ActiveRecord::Base.connection.execute("SET session_replication_role = 'origin'")
    when 'mysql'
      ActiveRecord::Base.connection.execute("SET FOREIGN_KEY_CHECKS = 1")
    end
    
    puts "All tables truncated"
  end
end

# Make db tasks available as top-level commands
task :db => 'db:migrate_status'