# Ragdoll::Core

Database-oriented multi-modal RAG (Retrieval-Augmented Generation) library built on ActiveRecord. Features PostgreSQL + pgvector for high-performance semantic search, polymorphic content architecture, and dual metadata design for sophisticated document analysis.

## Quick Start

```ruby
require 'ragdoll-core'

# Configure with PostgreSQL + pgvector (or SQLite for development)
Ragdoll.configure do |config|
  config.llm_provider = :openai
  config.embedding_model = 'text-embedding-3-small'
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
  # Or for development/testing:
  # config.database_config = {
  #   adapter: 'sqlite3',
  #   database: File.join(Dir.home, '.ragdoll', 'ragdoll.sqlite3'),
  #   auto_migrate: true
  # }

  # Logging configuration
  config.log_level = :warn
  config.log_file = File.join(Dir.home, '.ragdoll', 'ragdoll.log')
end

# Add documents - returns detailed result
result = Ragdoll.add_document(path: 'research_paper.pdf')
puts result[:message]  # "Document 'research_paper' added successfully with ID 123"
doc_id = result[:document_id]

# Check document status
status = Ragdoll.document_status(id: doc_id)
puts status[:message]  # Shows processing status and embeddings count

# Search across content
results = Ragdoll.search(query: 'neural networks')

# Get detailed document information
document = Ragdoll.get_document(id: doc_id)
```

## High-Level API

The `Ragdoll` module provides a convenient high-level API for common operations:

### Document Management

```ruby
# Add single document - returns detailed result hash
result = Ragdoll.add_document(path: 'document.pdf')
puts result[:success]         # true
puts result[:document_id]     # "123"
puts result[:message]         # "Document 'document' added successfully with ID 123"
puts result[:embeddings_queued] # true

# Check document processing status
status = Ragdoll.document_status(id: result[:document_id])
puts status[:status]          # "processed"
puts status[:embeddings_count] # 15
puts status[:embeddings_ready] # true
puts status[:message]         # "Document processed successfully with 15 embeddings"

# Get detailed document information
document = Ragdoll.get_document(id: result[:document_id])
puts document[:title]         # "document"
puts document[:status]        # "processed"
puts document[:embeddings_count] # 15
puts document[:content_length]   # 5000

# Update document metadata
Ragdoll.update_document(id: result[:document_id], title: 'New Title')

# Delete document
Ragdoll.delete_document(id: result[:document_id])

# List all documents
documents = Ragdoll.list_documents(limit: 10)

# System statistics
stats = Ragdoll.stats
puts stats[:total_documents]  # 50
puts stats[:total_embeddings] # 1250
```

### Search and Retrieval

```ruby
# Semantic search across all content types
results = Ragdoll.search(query: 'artificial intelligence')

# Search specific content types
text_results = Ragdoll.search(query: 'machine learning', content_type: 'text')
image_results = Ragdoll.search(query: 'neural network diagram', content_type: 'image')
audio_results = Ragdoll.search(query: 'AI discussion', content_type: 'audio')

# Advanced search with metadata filters
results = Ragdoll.search(
  query: 'deep learning',
  classification: 'research',
  keywords: ['AI', 'neural networks'],
  tags: ['technical']
)

# Get context for RAG applications
context = Ragdoll.get_context(query: 'machine learning', limit: 5)

# Enhanced prompt with context
enhanced = Ragdoll.enhance_prompt(
  prompt: 'What is machine learning?',
  context_limit: 5
)

# Hybrid search combining semantic and full-text
results = Ragdoll.hybrid_search(
  query: 'neural networks',
  semantic_weight: 0.7,
  text_weight: 0.3
)
```

### System Operations

```ruby
# Get system statistics
stats = Ragdoll.stats
# Returns information about documents, content types, embeddings, etc.

# Health check
healthy = Ragdoll.healthy?

# Get configuration
config = Ragdoll.configuration

# Reset configuration (useful for testing)
Ragdoll.reset_configuration!
```

### Configuration

```ruby
# Configure the system
Ragdoll::Core.configure do |config|
  # LLM Provider
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']

  # Embedding model
  config.embedding_model = 'text-embedding-3-small'

  # PostgreSQL with pgvector
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }

  # Or SQLite for development
  # config.database_config = {
  #   adapter: 'sqlite3',
  #   database: File.join(Dir.home, '.ragdoll', 'ragdoll.sqlite3'),
  #   auto_migrate: true
  # }

  # Logging configuration
  config.log_level = :warn  # :debug, :info, :warn, :error, :fatal
  config.log_file = File.join(Dir.home, '.ragdoll', 'ragdoll.log')

  # Processing settings
  config.chunk_size = 1000
  config.chunk_overlap = 200
  config.search_similarity_threshold = 0.7
  config.max_search_results = 10
end
```

## Current Implementation Status

### ✅ **Fully Implemented**
- **Text document processing**: PDF, DOCX, HTML, Markdown, plain text files
- **Embedding generation**: Text chunking and vector embedding creation
- **Database schema**: Multi-modal polymorphic architecture with PostgreSQL/SQLite
- **Dual metadata architecture**: Separate LLM-generated content analysis and file properties
- **Search functionality**: Semantic search with cosine similarity and usage analytics
- **Document management**: Add, update, delete, list operations
- **Background processing**: ActiveJob integration for async embedding generation
- **LLM metadata generation**: AI-powered structured content analysis with schema validation
- **Logging**: Configurable file-based logging with multiple levels

### 🚧 **In Development**
- **Image processing**: Framework exists but vision AI integration needs completion
- **Audio processing**: Framework exists but speech-to-text integration needs completion
- **Hybrid search**: Combining semantic and full-text search capabilities

### 📋 **Planned Features**
- **Multi-modal search**: Search across text, image, and audio content types
- **Content-type specific embedding models**: Different models for text, image, audio
- **Enhanced metadata schemas**: Domain-specific metadata templates

## Architecture Highlights

### Dual Metadata Design

Ragdoll uses a sophisticated dual metadata architecture to separate concerns:

- **`metadata` (JSON)**: LLM-generated content analysis including summary, keywords, classification, topics, sentiment, and domain-specific insights
- **`file_metadata` (JSON)**: System-generated file properties including size, MIME type, dimensions, processing parameters, and technical characteristics

This separation enables both semantic search operations on content meaning and efficient file management operations.

### Polymorphic Multi-Modal Architecture

The database schema uses polymorphic associations to elegantly support multiple content types:

- **Documents**: Central entity with dual metadata columns
- **Content Types**: Specialized tables for `text_contents`, `image_contents`, `audio_contents`
- **Embeddings**: Unified vector storage via polymorphic `embeddable` associations

## Text Document Processing (Current)

Currently, Ragdoll processes text documents through:

1. **Content Extraction**: Extracts text from PDF, DOCX, HTML, Markdown, and plain text
2. **Metadata Generation**: AI-powered analysis creates structured content metadata
3. **Text Chunking**: Splits content into manageable chunks with configurable size/overlap
4. **Embedding Generation**: Creates vector embeddings using OpenAI or other providers
5. **Database Storage**: Stores in polymorphic multi-modal architecture with dual metadata
6. **Search**: Semantic search using cosine similarity with usage analytics

### Example Usage
```ruby
# Add a text document
result = Ragdoll.add_document(path: 'document.pdf')

# Check processing status
status = Ragdoll.document_status(id: result[:document_id])

# Search the content
results = Ragdoll.search(query: 'machine learning')
```

## PostgreSQL + pgvector Configuration

### Database Setup

```bash
# Install PostgreSQL and pgvector
brew install postgresql pgvector  # macOS
# or
apt-get install postgresql postgresql-contrib  # Ubuntu

# Enable pgvector extension
psql -d ragdoll_production -c "CREATE EXTENSION IF NOT EXISTS vector;"
```

### Configuration Example

```ruby
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    pool: 20,
    auto_migrate: true
  }
end
```

## Performance Features

- **Native pgvector**: Hardware-accelerated similarity search
- **IVFFlat indexing**: Fast approximate nearest neighbor search
- **Polymorphic embeddings**: Unified search across content types
- **Batch processing**: Efficient bulk operations
- **Background jobs**: Asynchronous document processing
- **Connection pooling**: High-concurrency support

## Installation

```bash
# Install system dependencies
brew install postgresql pgvector  # macOS

# Install gem
gem install ragdoll-core

# Or add to Gemfile
gem 'ragdoll-core'
```

## Requirements

- **Ruby**: 3.0+
- **PostgreSQL**: 12+ with pgvector extension
- **Dependencies**: activerecord, pg, pgvector, neighbor, ruby_llm

## Related Projects

- **ragdoll-cli**: Standalone CLI application using ragdoll-core
- **ragdoll-rails**: Rails engine with web interface for ragdoll-core

## Key Design Principles

1. **Database-Oriented**: Built on ActiveRecord with PostgreSQL + pgvector for production performance
2. **Multi-Modal First**: Text, image, and audio content as first-class citizens via polymorphic architecture
3. **Dual Metadata Design**: Separates LLM-generated content analysis from file properties
4. **LLM-Enhanced**: Structured metadata generation with schema validation using latest AI capabilities
5. **High-Level API**: Simple, intuitive interface for complex operations
6. **Scalable**: Designed for production workloads with background processing and proper indexing
7. **Extensible**: Easy to add new content types and embedding models through polymorphic design
