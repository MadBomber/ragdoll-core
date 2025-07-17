# frozen_string_literal: true

# =============================================================================
# Ragdoll Core - Complete IRB Configuration
# =============================================================================
# This file contains all possible configuration options for Ragdoll Core.
# Uncomment and modify settings as needed for your environment.
#
# Environment variables are used as defaults where applicable.
# =============================================================================

require_relative 'lib/ragdoll'

def table_counts
  ActiveRecord::Base.connection.tables.each_with_object({}) do |table, counts|
    # Skip system tables if necessary
    next if ['schema_migrations', 'ar_internal_metadata'].include?(table)

    # Get the count of records in the table
    counts[table] = ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM #{table}").first["count"]
  end
end


# Configure Ragdoll with all available options
Ragdoll::Core.configure do |config|

  # =============================================================================
  # LLM PROVIDER CONFIGURATION
  # =============================================================================

  # Primary LLM provider for general operations
  config.llm_provider = :openai  # Options: :openai, :anthropic, :google, :azure, :ollama, :huggingface, :openrouter

  # =============================================================================
  # LLM API KEYS AND CONFIGURATION
  # =============================================================================

  # OpenAI Configuration
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.llm_config = {
    openai: {
      api_key: ENV['OPENAI_API_KEY'],
      organization: ENV['OPENAI_ORGANIZATION'],
      project: ENV['OPENAI_PROJECT']
    },

    # Anthropic Configuration
    anthropic: {
      api_key: ENV['ANTHROPIC_API_KEY']
    },

    # Google Configuration
    google: {
      api_key: ENV['GOOGLE_API_KEY'],
      project_id: ENV['GOOGLE_PROJECT_ID']
    },

    # Azure OpenAI Configuration
    azure: {
      api_key: ENV['AZURE_OPENAI_API_KEY'],
      endpoint: ENV['AZURE_OPENAI_ENDPOINT'],
      api_version: ENV['AZURE_OPENAI_API_VERSION'] || '2024-02-01'
    },

    # Ollama Configuration (Local)
    ollama: {
      endpoint: ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434'
    },

    # Hugging Face Configuration
    huggingface: {
      api_key: ENV['HUGGINGFACE_API_KEY']
    },

    # OpenRouter Configuration
    openrouter: {
      api_key: ENV['OPENROUTER_API_KEY']
    }
  }

  # =============================================================================
  # EMBEDDING CONFIGURATION
  # =============================================================================

  # Primary embedding provider
  config.embedding_provider = :openai  # Options: :openai, :anthropic, :google, :azure, :ollama, :huggingface

  # Embedding model to use
  config.embedding_model = 'text-embedding-3-small'  # Options: text-embedding-3-small, text-embedding-3-large, text-embedding-ada-002

  # Maximum embedding dimensions supported
  config.max_embedding_dimensions = 3072  # Supports up to text-embedding-3-large

  # Cache embeddings to avoid regeneration
  config.cache_embeddings = true

  # =============================================================================
  # MODEL CONFIGURATION FOR SPECIFIC TASKS
  # =============================================================================

  # Default model for general LLM operations
  config.default_model = 'gpt-4'

  # Models for specific tasks (format: "provider/model" or just "model")
  config.summary_provider_model = 'openai/gpt-4'
  config.keywords_provider_model = 'openai/gpt-4'
  config.embeddings_provider_model = 'openai/text-embedding-3-small'

  # Summary model (if nil, uses default_model)
  config.summary_model = nil

  # =============================================================================
  # TEXT PROCESSING CONFIGURATION
  # =============================================================================

  # Text chunking settings
  config.chunk_size = 1000          # Characters per chunk
  config.chunk_overlap = 200        # Character overlap between chunks

  # Document summarization settings
  config.enable_document_summarization = true
  config.summary_max_length = 300           # Maximum summary length in characters
  config.summary_min_content_length = 300   # Minimum content length to generate summary

  # Default prompt template (nil uses built-in template)
  config.prompt_template = nil

  # =============================================================================
  # SEARCH CONFIGURATION
  # =============================================================================

  # Search similarity threshold (0.0 to 1.0)
  config.search_similarity_threshold = 0.7

  # Maximum search results to return
  config.max_search_results = 10

  # =============================================================================
  # ANALYTICS AND TRACKING
  # =============================================================================

  # Enable search analytics
  config.enable_search_analytics = true

  # Enable usage tracking for embeddings
  config.enable_usage_tracking = true

  # Usage ranking configuration
  config.usage_ranking_enabled = true
  config.usage_recency_weight = 0.3      # Weight for recent usage
  config.usage_frequency_weight = 0.7    # Weight for frequent usage
  config.usage_similarity_weight = 1.0   # Weight for similarity score

  # =============================================================================
  # DATABASE CONFIGURATION
  # =============================================================================

  # Choose between PostgreSQL (production) or SQLite (development)

  # PostgreSQL Configuration (Recommended for production)
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: ENV['RAGDOLL_DATABASE_PASSWORD'] || 'ragdoll',
    host: ENV['DATABASE_HOST'] || 'localhost',
    port: ENV['DATABASE_PORT'] || 5432,
    pool: 20,                    # Connection pool size
    timeout: 5000,               # Connection timeout in milliseconds
    auto_migrate: true,          # Automatically run migrations
    logger: nil                  # Database logger (nil for no logging)
  }

  # SQLite Configuration (Alternative for development/testing)
  # config.database_config = {
  #   adapter: 'sqlite3',
  #   database: File.join(Dir.home, '.ragdoll', 'ragdoll.sqlite3'),
  #   timeout: 5000,
  #   auto_migrate: true,
  #   logger: nil
  # }

  # =============================================================================
  # LOGGING CONFIGURATION
  # =============================================================================

  # Log level (:debug, :info, :warn, :error, :fatal)
  config.log_level = :warn

  # Log file location
  config.log_file = File.join(Dir.home, '.ragdoll', 'ragdoll.log')

  # Alternative log file locations:
  # config.log_file = File.join(Dir.pwd, 'log', 'ragdoll.log')      # Project log directory
  # config.log_file = '/var/log/ragdoll/ragdoll.log'                # System log directory

end

# =============================================================================
# HELPER METHODS FOR IRB SESSION
# =============================================================================

# Quick access to configuration
def ragdoll_config
  Ragdoll::Core.configuration
end

# Quick access to client
def ragdoll_client
  @ragdoll_client ||= Ragdoll::Core.client
end

# Quick stats
def ragdoll_stats
  Ragdoll::Core.stats
end

# Quick document count (safe)
def doc_count
  return 0 unless table_exists?('ragdoll_documents')
  Ragdoll::Core::Models::Document.count
rescue StandardError
  0
end

# Quick embedding count (safe)
def embedding_count
  return 0 unless table_exists?('ragdoll_embeddings')
  Ragdoll::Core::Models::Embedding.count
rescue StandardError
  0
end

# Check if table exists
def table_exists?(table_name)
  ActiveRecord::Base.connection.table_exists?(table_name)
rescue StandardError
  false
end

# Quick health check (safe)
def ragdoll_health
  {
    healthy: Ragdoll::Core.healthy?,
    documents: doc_count,
    embeddings: embedding_count,
    database_connected: Ragdoll::Core::Database.connected?,
    tables_exist: %w[ragdoll_documents ragdoll_embeddings ragdoll_text_contents ragdoll_image_contents ragdoll_audio_contents].map { |t| [t, table_exists?(t)] }.to_h
  }
rescue StandardError => e
  {
    healthy: false,
    error: e.message,
    database_connected: false,
    documents: 0,
    embeddings: 0
  }
end

# =============================================================================
# DEVELOPMENT HELPERS
# =============================================================================

# Run database migrations
def migrate_database!
  puts "🔄 Running database migrations..."
  Ragdoll::Core::Database.migrate!
  puts "✅ Database migrations complete"
rescue StandardError => e
  puts "❌ Migration failed: #{e.message}"
end

# Reset database (WARNING: Destroys all data!)
def reset_database!
  puts "⚠️  WARNING: This will destroy all data!"
  print "Are you sure? (yes/no): "
  response = gets.chomp
  if response.downcase == 'yes'
    Ragdoll::Core::Database.reset!
    puts "✅ Database reset complete"
  else
    puts "❌ Database reset cancelled"
  end
end

# Show current configuration
def show_config
  config = ragdoll_config
  puts "\n=== Ragdoll Configuration ==="
  puts "LLM Provider: #{config.llm_provider}"
  puts "Embedding Model: #{config.embedding_model}"
  puts "Chunk Size: #{config.chunk_size}"
  puts "Chunk Overlap: #{config.chunk_overlap}"
  puts "Search Threshold: #{config.search_similarity_threshold}"
  puts "Max Results: #{config.max_search_results}"
  puts "Log Level: #{config.log_level}"
  puts "Log File: #{config.log_file}"
  puts "Database: #{config.database_config[:adapter]}"
  puts "Auto Migrate: #{config.database_config[:auto_migrate]}"
  puts "========================="
end

# Show database info
def show_database_info
  config = ragdoll_config.database_config
  puts "\n=== Database Configuration ==="
  puts "Adapter: #{config[:adapter]}"
  puts "Database: #{config[:database]}"
  puts "Host: #{config[:host]}" if config[:host]
  puts "Port: #{config[:port]}" if config[:port]
  puts "Username: #{config[:username]}" if config[:username]
  puts "Pool: #{config[:pool]}" if config[:pool]
  puts "Timeout: #{config[:timeout]}"
  puts "Auto Migrate: #{config[:auto_migrate]}"
  puts "Connected: #{Ragdoll::Core::Database.connected?}"
  puts "========================="
end

# Show LLM configuration
def show_llm_config
  config = ragdoll_config
  puts "\n=== LLM Configuration ==="
  puts "Primary Provider: #{config.llm_provider}"
  puts "Embedding Provider: #{config.embedding_provider}"
  puts "Embedding Model: #{config.embedding_model}"
  puts "Default Model: #{config.default_model}"
  puts "Summary Model: #{config.summary_provider_model}"
  puts "Keywords Model: #{config.keywords_provider_model}"
  puts "Embeddings Model: #{config.embeddings_provider_model}"
  puts "========================="
end

# List all available helper methods
def help
  puts "\n=== Available Helper Methods ==="
  puts "ragdoll_config        - Access configuration"
  puts "ragdoll_client        - Access client instance"
  puts "ragdoll_stats         - System statistics"
  puts "ragdoll_health        - Health check (safe)"
  puts "doc_count             - Document count (safe)"
  puts "embedding_count       - Embedding count (safe)"
  puts "table_exists?(name)   - Check if table exists"
  puts "migrate_database!     - Run database migrations"
  puts "reset_database!       - Reset database (destroys all data!)"
  puts "show_config           - Show current configuration"
  puts "show_database_info    - Show database configuration"
  puts "show_llm_config       - Show LLM configuration"
  puts "table_counts          - Show record counts for all tables"
  puts "help                  - Show this help message"
  puts "========================="
end

# =============================================================================
# STARTUP MESSAGE
# =============================================================================

puts "\n🎯 Ragdoll Core loaded!"

# Check if tables exist and show appropriate message
health = ragdoll_health
if health[:tables_exist].values.all?
  puts "📊 Health: #{health}"
  puts "✅ All database tables exist"
else
  puts "⚠️  Database tables missing!"
  puts "   Missing tables: #{health[:tables_exist].select { |t, exists| !exists }.keys.join(', ')}"
  puts "   Run 'migrate_database!' to create tables"
end

puts "⚙️  Use 'show_config' to see current configuration"
puts "🔍 Use 'ragdoll_health' to check system health"
puts "❓ Use 'help' to see all available methods"
puts "🗄️  Use 'migrate_database!' to run migrations"
puts "⚠️  Use 'reset_database!' to reset database (destroys all data!)"
puts "=" * 60
