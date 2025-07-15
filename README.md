# Ragdoll::Core

Multi-modal RAG (Retrieval-Augmented Generation) library with PostgreSQL and pgvector for high-performance semantic search. Supports text, image, and audio content with LLM-generated structured metadata.

## Quick Start

```ruby
require 'ragdoll-core'

# Configure with PostgreSQL + pgvector
Ragdoll.configure do |config|
  config.llm_provider = :openai
  config.embedding_models = {
    text: 'text-embedding-3-large',
    image: 'clip-vit-large-patch14', 
    audio: 'whisper-embedding-v1'
  }
  config.database_config = {
    adapter: 'postgresql',
    database: 'ragdoll_production',
    username: 'ragdoll',
    password: ENV['DATABASE_PASSWORD'],
    host: 'localhost',
    port: 5432,
    auto_migrate: true
  }
end

# Add multi-modal documents
doc_id = Ragdoll.add_document(path: 'research_paper.pdf')      # Text content
img_id = Ragdoll.add_document(path: 'diagram.png')             # Image content  
audio_id = Ragdoll.add_document(path: 'podcast.mp3')           # Audio content

# Search across all content types
results = Ragdoll.search('neural networks')

# Get document information
document = Ragdoll.get_document(doc_id)
```

## High-Level API

The `Ragdoll` module provides a convenient high-level API for common operations:

### Document Management

```ruby
# Add single document
doc_id = Ragdoll.add_document(path: 'document.pdf')
doc_id = Ragdoll.add_document(path: 'document.docx', title: 'Custom Title')

# Add image document
img_id = Ragdoll.add_document(path: 'diagram.png', document_type: 'image')

# Add audio document  
audio_id = Ragdoll.add_document(path: 'podcast.mp3', document_type: 'audio')

# Add directory of documents
results = Ragdoll.add_directory(path: '/documents', recursive: true)

# Get document
document = Ragdoll.get_document(id: doc_id)

# Update document metadata
Ragdoll.update_document(id: doc_id, title: 'New Title')

# Delete document
Ragdoll.delete_document(id: doc_id)

# List all documents
documents = Ragdoll.list_documents(limit: 10)

# List by document type
text_docs = Ragdoll.list_documents(document_type: 'text')
image_docs = Ragdoll.list_documents(document_type: 'image')
audio_docs = Ragdoll.list_documents(document_type: 'audio')
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
Ragdoll.configure do |config|
  # LLM Provider
  config.llm_provider = :openai
  config.openai_api_key = ENV['OPENAI_API_KEY']
  
  # Multi-modal embedding models
  config.embedding_models = {
    text: 'text-embedding-3-large',
    image: 'clip-vit-large-patch14',
    audio: 'whisper-embedding-v1'
  }
  
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
  
  # Processing settings
  config.chunk_size = 1000
  config.chunk_overlap = 200
  config.batch_size = 100
end
```

## Multi-Modal Content Support

Ragdoll automatically detects and processes different content types:

### Supported Content Types

- **Text**: PDF, DOCX, HTML, Markdown, plain text files
- **Image**: PNG, JPG, GIF, WebP with AI-generated descriptions
- **Audio**: MP3, WAV, M4A with speech-to-text transcription

### Automatic Processing Pipeline

When you add a document, Ragdoll automatically:

1. **Content Extraction**: Extracts text, analyzes images, or transcribes audio
2. **Embedding Generation**: Creates embeddings using content-type-specific models
3. **Metadata Generation**: Uses LLMs to generate structured metadata
4. **Indexing**: Indexes content for fast search and retrieval

### LLM-Generated Structured Metadata

Each content type gets AI-generated metadata tailored to its characteristics:

- **Text documents**: Summary, keywords, classification, topics, sentiment, reading time
- **Image documents**: Description, objects, scene type, colors, style, mood  
- **Audio documents**: Content type, transcript summary, speakers, key quotes, language

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
Ragdoll.configure do |config|
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

1. **Multi-Modal First**: Text, image, and audio content as first-class citizens
2. **PostgreSQL Optimized**: Leverages PostgreSQL + pgvector for maximum performance
3. **LLM-Enhanced**: Structured metadata generation using latest AI capabilities
4. **High-Level API**: Simple, intuitive interface for complex operations
5. **Scalable**: Designed for production workloads with proper indexing
6. **Extensible**: Easy to add new content types and embedding models