# Ragdoll::Core

Core RAG (Retrieval-Augmented Generation) functionality for document processing and semantic search. This gem provides framework-agnostic RAG capabilities that can be used in standalone applications, CLI tools, and web frameworks.

## Features

- Document processing for PDF, DOCX, text, and HTML files
- Text chunking with intelligent boundary detection
- Embedding generation with multiple LLM providers
- Semantic search with cosine similarity
- Pluggable storage backends (memory, file, or custom)
- Usage tracking and analytics
- Framework-agnostic design

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ragdoll-core'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install ragdoll-core
```

## Usage

### Basic Setup

```ruby
require 'ragdoll-core'

# Configure the client
Ragdoll::Core.configure do |config|
  config.llm_provider = :openai
  config.embedding_model = 'text-embedding-3-small'
  config.storage_backend = :file
  config.storage_config = { directory: '~/.ragdoll' }
end

# Create a client
client = Ragdoll::Core.client
```

### Adding Documents

```ruby
# Add a file
doc_id = client.add_file('path/to/document.pdf')

# Add text content
doc_id = client.add_text('Some content here', title: 'My Document')

# Add an entire directory
results = client.add_directory('path/to/docs', recursive: true)
```

### Searching

```ruby
# Basic search
results = client.search('What is machine learning?')

# Get context for RAG applications
context = client.get_context('machine learning concepts', limit: 5)

# Enhanced prompts
enhanced = client.enhance_prompt('Explain neural networks', context_limit: 3)
puts enhanced[:enhanced_prompt]
```

### Configuration

```ruby
Ragdoll::Core.configure do |config|
  # LLM Provider settings
  config.llm_provider = :openai
  config.embedding_provider = :openai
  config.embedding_model = 'text-embedding-3-small'
  
  # Text processing
  config.chunk_size = 1000
  config.chunk_overlap = 200
  
  # Search settings
  config.search_similarity_threshold = 0.7
  config.max_search_results = 10
  
  # Storage backend
  config.storage_backend = :file  # or :memory
  config.storage_config = { directory: '~/.ragdoll' }
  
  # API keys (or set via environment variables)
  config.openai_api_key = 'your-api-key'
end
```

### Storage Backends

#### Memory Storage (for testing/development)
```ruby
config.storage_backend = :memory
config.storage_config = {}
```

#### File Storage (for standalone applications)
```ruby
config.storage_backend = :file
config.storage_config = { directory: '~/.ragdoll' }
```

#### Custom Storage (implement your own)
```ruby
class MyStorage < Ragdoll::Core::Storage::Base
  # Implement required methods...
end

config.storage_backend = :custom
config.storage_config = { adapter: MyStorage }
```

### Supported Document Types

- PDF files (`.pdf`)
- Microsoft Word documents (`.docx`)
- Text files (`.txt`)
- Markdown files (`.md`, `.markdown`)
- HTML files (`.html`, `.htm`)

### Text Chunking

```ruby
# Basic chunking
chunks = Ragdoll::Core::TextChunker.chunk(text, 
  chunk_size: 1000, 
  chunk_overlap: 200
)

# Structure-aware chunking
chunks = Ragdoll::Core::TextChunker.chunk_by_structure(text, 
  max_chunk_size: 1000
)

# Code-aware chunking
chunks = Ragdoll::Core::TextChunker.chunk_code(code_text, 
  max_chunk_size: 1000
)
```

## Architecture

Ragdoll::Core is designed to be the foundation for RAG applications with a clean separation of concerns:

- **DocumentProcessor**: Handles parsing of various document formats
- **TextChunker**: Intelligently splits text into manageable chunks
- **EmbeddingService**: Generates vector embeddings using various LLM providers
- **SearchEngine**: Performs semantic search using cosine similarity
- **Storage**: Pluggable backends for storing documents and embeddings
- **Client**: High-level interface that ties everything together

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/MadBomber/ragdoll-core.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).