# Installation & Setup

This comprehensive guide covers installing Ragdoll-Core in various environments, from development setup to production deployment with all dependencies and configuration options.

## System Requirements

### Minimum Requirements

- **Ruby**: 3.0 or higher
- **Database**: PostgreSQL 12+ (with pgvector) or SQLite 3.8+
- **Memory**: 2 GB RAM minimum, 4 GB recommended
- **Storage**: 1 GB free space (plus document storage)
- **Network**: Internet access for LLM API calls

### Recommended Production Requirements

- **Ruby**: 3.2+ 
- **Database**: PostgreSQL 14+ with pgvector extension
- **Memory**: 8 GB RAM or more
- **Storage**: 10 GB+ SSD storage
- **CPU**: 4+ cores for background processing
- **Network**: Stable internet with low latency to LLM providers

## Installation Methods

### Method 1: Gem Installation (Recommended)

```bash
# Install the gem
gem install ragdoll-core

# Verify installation
ruby -e "require 'ragdoll-core'; puts Ragdoll::Core::VERSION"
```

### Method 2: Bundler (For Applications)

Add to your `Gemfile`:

```ruby
# Gemfile
gem 'ragdoll-core', '~> 0.1.0'

# Optional: specify database adapter
gem 'pg', '~> 1.5'        # PostgreSQL
gem 'sqlite3', '~> 1.6'   # SQLite

# Optional: background job adapter
gem 'sidekiq', '~> 7.0'   # For production background processing
```

Install dependencies:

```bash
bundle install
```

### Method 3: Development Installation

```bash
# Clone the repository
git clone https://github.com/madbomber/ragdoll-core.git
cd ragdoll-core

# Install dependencies
bundle install

# Run tests to verify installation
bundle exec rake test

# Install locally
bundle exec rake install
```

## Database Setup

### PostgreSQL with pgvector (Recommended for Production)

#### Installation

**Ubuntu/Debian:**
```bash
# Install PostgreSQL
sudo apt update
sudo apt install postgresql-14 postgresql-contrib-14

# Install pgvector
sudo apt install postgresql-14-pgvector

# Start PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

**macOS (Homebrew):**
```bash
# Install PostgreSQL
brew install postgresql@14

# Install pgvector
brew install pgvector

# Start PostgreSQL
brew services start postgresql@14
```

**CentOS/RHEL:**
```bash
# Install PostgreSQL
sudo dnf install postgresql14-server postgresql14-contrib

# Install pgvector
sudo dnf install postgresql14-pgvector

# Initialize and start
sudo postgresql-setup --initdb
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### Database Configuration

```bash
# Switch to postgres user
sudo -u postgres psql

# Create database and user
CREATE DATABASE ragdoll_development;
CREATE DATABASE ragdoll_test;
CREATE DATABASE ragdoll_production;

CREATE USER ragdoll WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll;
GRANT ALL PRIVILEGES ON DATABASE ragdoll_test TO ragdoll;
GRANT ALL PRIVILEGES ON DATABASE ragdoll_production TO ragdoll;

# Enable pgvector extension on each database
\c ragdoll_development
CREATE EXTENSION vector;

\c ragdoll_test  
CREATE EXTENSION vector;

\c ragdoll_production
CREATE EXTENSION vector;

\q
```

#### pgvector Verification

```bash
# Test pgvector installation
psql -U ragdoll -d ragdoll_development -c "SELECT vector('[1,2,3]') <-> vector('[4,5,6]');"
# Should return a distance value
```

### SQLite (Development/Testing)

SQLite is included with Ruby and requires no additional setup:

```bash
# Verify SQLite version (3.8+ required)
sqlite3 --version

# If needed, install/upgrade SQLite
# Ubuntu/Debian
sudo apt install sqlite3 libsqlite3-dev

# macOS
brew install sqlite3

# CentOS/RHEL  
sudo dnf install sqlite sqlite-devel
```

### Database Migration

```ruby
# Create and configure Ragdoll client
require 'ragdoll-core'

Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',  # or 'sqlite3'
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: 'your_secure_password',
    host: 'localhost',
    port: 5432,
    auto_migrate: true  # Automatically run migrations
  }
end

# The schema will be created automatically on first use
client = Ragdoll::Core.client
```

## LLM Provider Setup

### OpenAI (Recommended)

```bash
# Set your OpenAI API key
export OPENAI_API_KEY='sk-your-openai-api-key-here'

# Add to your shell profile for persistence
echo 'export OPENAI_API_KEY="sk-your-openai-api-key-here"' >> ~/.bashrc
source ~/.bashrc
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'  # Recommended
  # config.embedding_model = 'text-embedding-3-large'  # Higher quality
end
```

### Anthropic Claude

```bash
# Set your Anthropic API key
export ANTHROPIC_API_KEY='sk-ant-your-anthropic-key-here'
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  config.llm_provider = :anthropic
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.embedding_model = 'text-embedding-3-small'  # Still uses OpenAI for embeddings
  config.summary_model = 'claude-3-sonnet-20240229'
end
```

### Google Gemini

```bash
# Set your Google API key
export GOOGLE_API_KEY='your-google-api-key-here'
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  config.llm_provider = :google
  config.google_api_key = ENV['GOOGLE_API_KEY']
  config.summary_model = 'gemini-1.5-pro'
end
```

### Ollama (Local LLM)

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull models
ollama pull llama3:8b
ollama pull nomic-embed-text

# Start Ollama service
ollama serve
```

**Configuration:**
```ruby
Ragdoll::Core.configure do |config|
  config.llm_provider = :ollama
  config.ollama_url = 'http://localhost:11434'
  config.summary_model = 'llama3:8b'
  config.embedding_model = 'nomic-embed-text'
end
```

## Development Environment Setup

### Basic Development Configuration

Create a configuration file:

```ruby
# config/ragdoll.rb
require 'ragdoll-core'

Ragdoll::Core.configure do |config|
  # LLM Provider
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'
  
  # Development database
  config.database_config = {
    adapter: 'sqlite3',
    database: 'db/ragdoll_development.sqlite3',
    auto_migrate: true
  }
  
  # Development settings
  config.log_level = :debug
  config.log_file = nil  # Log to stdout
  config.chunk_size = 800
  config.chunk_overlap = 100
  config.enable_background_processing = false  # Synchronous for development
end
```

### Rails Integration

For Rails applications:

```ruby
# config/initializers/ragdoll.rb
Ragdoll::Core.configure do |config|
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'
  
  # Use Rails database configuration
  config.database_config = Rails.application.config.database_configuration[Rails.env]
  
  config.log_level = Rails.logger.level
  config.log_file = Rails.root.join('log', 'ragdoll.log').to_s
end
```

### Environment-Specific Configuration

```ruby
# config/environments/development.rb
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'sqlite3',
    database: 'db/ragdoll_development.sqlite3',
    auto_migrate: true
  }
  config.log_level = :debug
  config.enable_background_processing = false
end

# config/environments/test.rb  
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'sqlite3',
    database: ':memory:',
    auto_migrate: true
  }
  config.log_level = :fatal
  config.enable_background_processing = false
  # Use test doubles for LLM calls
  config.llm_provider = :test
end

# config/environments/production.rb
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    url: ENV['DATABASE_URL'],
    pool: 25,
    auto_migrate: false
  }
  config.log_level = :info
  config.log_format = :json
  config.enable_background_processing = true
end
```

## Background Processing Setup

### Sidekiq (Recommended for Production)

```bash
# Install Redis
# Ubuntu/Debian
sudo apt install redis-server

# macOS
brew install redis

# Start Redis
redis-server
```

**Configuration:**
```ruby
# Gemfile
gem 'sidekiq', '~> 7.0'
gem 'redis', '~> 5.0'

# config/initializers/sidekiq.rb
Sidekiq.configure_server do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV['REDIS_URL'] || 'redis://localhost:6379/0' }
end

# Enable background processing in Ragdoll
Ragdoll::Core.configure do |config|
  config.enable_background_processing = true
  config.job_queue_adapter = :sidekiq
end
```

**Start Sidekiq workers:**
```bash
# Development
bundle exec sidekiq

# Production with specific queues
bundle exec sidekiq -q embeddings:3 -q processing:2 -q analysis:1
```

### Alternative: Async (Development)

```ruby
# For development/testing without Redis
Ragdoll::Core.configure do |config|
  config.enable_background_processing = true
  config.job_queue_adapter = :async
end
```

## File Storage Configuration

### Local Storage (Development)

```ruby
Ragdoll::Core.configure do |config|
  config.storage_config = {
    type: :file,
    path: File.join(Dir.home, '.ragdoll', 'storage'),
    cache_path: File.join(Dir.home, '.ragdoll', 'cache')
  }
end
```

### Production Storage

```ruby
# AWS S3
Ragdoll::Core.configure do |config|
  config.storage_config = {
    type: :s3,
    bucket: ENV['S3_BUCKET'],
    region: ENV['AWS_REGION'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
  }
end

# Google Cloud Storage
Ragdoll::Core.configure do |config|
  config.storage_config = {
    type: :gcs,
    bucket: ENV['GCS_BUCKET'],
    project: ENV['GCP_PROJECT_ID'],
    credentials: ENV['GOOGLE_APPLICATION_CREDENTIALS']
  }
end
```

## Verification and Testing

### Basic Verification

```ruby
# test_installation.rb
require 'ragdoll-core'

# Configure with minimal settings
Ragdoll::Core.configure do |config|
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.embedding_model = 'text-embedding-3-small'
  
  config.database_config = {
    adapter: 'sqlite3',
    database: ':memory:',
    auto_migrate: true
  }
end

# Test basic functionality
puts "Testing Ragdoll-Core installation..."

# Test database connection
client = Ragdoll::Core.client
puts "✓ Database connection successful"

# Test LLM connection
result = client.add_text(
  content: "This is a test document for verification.",
  title: "Installation Test"
)
puts "✓ Document addition successful: #{result[:message]}"

# Test search
search_results = client.search(query: "test document")
puts "✓ Search functionality working: #{search_results.size} results"

# Test system health
health = client.health_check
puts "✓ System health: #{health[:status]}"

puts "\nInstallation verification complete! 🎉"
puts "Ragdoll-Core is ready to use."
```

Run the verification:
```bash
ruby test_installation.rb
```

### Component Testing

```bash
# Test database connection
ruby -e "
require 'ragdoll-core'
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_development',
    username: 'ragdoll',
    password: 'your_password',
    host: 'localhost'
  }
end
puts 'Database connection: ' + (Ragdoll::Core::Database.connection.active? ? 'OK' : 'FAILED')
"

# Test LLM provider
ruby -e "
require 'ragdoll-core'
puts 'OpenAI API: ' + (ENV['OPENAI_API_KEY'] ? 'OK' : 'MISSING')
"

# Test pgvector
psql -U ragdoll -d ragdoll_development -c "SELECT vector('[1,2,3]') <-> vector('[4,5,6]');"
```

## Troubleshooting

### Common Installation Issues

#### 1. Database Connection Errors

**Error:** `PG::ConnectionBad: could not connect to server`

**Solutions:**
```bash
# Check PostgreSQL status
sudo systemctl status postgresql

# Start PostgreSQL if stopped
sudo systemctl start postgresql

# Check connection parameters
psql -U ragdoll -d ragdoll_development -h localhost

# Verify pg_hba.conf allows connections
sudo nano /etc/postgresql/14/main/pg_hba.conf
# Add: local   all   ragdoll   md5
```

#### 2. pgvector Extension Issues

**Error:** `PG::UndefinedFile: could not open extension control file`

**Solutions:**
```bash
# Reinstall pgvector
sudo apt remove postgresql-14-pgvector
sudo apt install postgresql-14-pgvector

# Manually install extension
sudo -u postgres psql -d ragdoll_development -c "CREATE EXTENSION vector;"
```

#### 3. Ruby Gem Dependencies

**Error:** `LoadError: cannot load such file`

**Solutions:**
```bash
# Update bundler
gem update bundler

# Clean and reinstall
bundle clean --force
bundle install

# Check Ruby version
ruby --version  # Should be 3.0+
```

#### 4. LLM API Issues

**Error:** `OpenAI API key not set`

**Solutions:**
```bash
# Check environment variable
echo $OPENAI_API_KEY

# Set temporarily
export OPENAI_API_KEY='sk-your-key-here'

# Add to shell profile permanently
echo 'export OPENAI_API_KEY="sk-your-key-here"' >> ~/.bashrc
source ~/.bashrc
```

#### 5. Permission Issues

**Error:** `Permission denied` for database or file operations

**Solutions:**
```bash
# Fix database permissions
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ragdoll_development TO ragdoll;"

# Fix file permissions
sudo chown -R $USER:$USER ~/.ragdoll/
chmod -R 755 ~/.ragdoll/
```

### Performance Issues

#### Slow Embedding Generation

```ruby
# Optimize configuration for better performance
Ragdoll::Core.configure do |config|
  config.chunk_size = 800        # Smaller chunks for faster processing
  config.embedding_model = 'text-embedding-3-small'  # Faster model
  config.enable_background_processing = true         # Process async
end
```

#### Database Performance

```sql
-- Add indexes for better query performance
CREATE INDEX CONCURRENTLY idx_embeddings_vector_search 
ON ragdoll_embeddings USING ivfflat (embedding_vector vector_cosine_ops);

-- Update statistics
ANALYZE ragdoll_embeddings;
```

### Getting Help

1. **Check Documentation**: Review the complete documentation in `docs/`
2. **Enable Debug Logging**: Set `config.log_level = :debug`
3. **Health Check**: Run `Ragdoll.health_check` to identify issues
4. **GitHub Issues**: Report bugs and feature requests
5. **Community**: Join discussions and get help from other users

## Next Steps

After successful installation:

1. **Quick Start**: Follow the [Quick Start Guide](quick-start.md) for basic usage
2. **Configuration**: Read the [Configuration Guide](configuration.md) for advanced setup
3. **API Reference**: Explore the [Client API Reference](api-client.md)
4. **Production Deployment**: Plan your [Production Deployment](deployment.md)

Congratulations! You now have Ragdoll-Core installed and ready to build sophisticated document intelligence applications.