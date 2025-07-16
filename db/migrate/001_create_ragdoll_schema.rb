# frozen_string_literal: true

# Migration: Create Complete Ragdoll Schema
#
# This migration creates the complete database schema for the Ragdoll RAG system
# including documents, content types, embeddings, and ActiveStorage support.

class CreateRagdollSchema < ActiveRecord::Migration[7.0]
  def change
    # Enable pgvector extension (if not already enabled)
    enable_extension 'vector' unless connection.extension_enabled?('vector')

    # === Documents Table ===
    create_table :ragdoll_documents,
                 comment: 'Core documents table with LLM-generated structured metadata' do |t|
      # Document identity
      t.string :location, null: false, comment: 'Source location of document (file path, URL, or identifier)'
      t.string :title, null: false, comment: 'Human-readable document title for display and search'

      # Document classification
      t.string :document_type, null: false, default: 'text',
                               comment: 'Document format type (text, image, audio, pdf, docx, html, markdown, mixed)'
      t.string :status, null: false, default: 'pending',
                        comment: 'Document processing status: pending, processing, processed, error'

      # LLM-generated structured metadata
      t.json :metadata, default: {},
             comment: 'LLM-generated structured metadata using document-type-specific schemas'

      # File properties and processing metadata
      t.json :file_metadata, default: {},
                             comment: 'File properties and processing metadata, separate from AI-generated content'

      # Shrine file attachment for documents
      t.text :file_data, comment: 'Shrine file attachment data (JSON)'

      # Standard timestamps
      t.timestamps null: false, comment: 'Standard creation and update timestamps'

      # Indexes
      t.index :location, comment: 'Index for document source lookup'
      t.index :title, comment: 'Index for title-based search'
      t.index :document_type, comment: 'Index for filtering by document type'
      t.index :status, comment: 'Index for filtering by processing status'
      t.index :created_at, comment: 'Index for chronological sorting'
      t.index %i[document_type status], comment: 'Composite index for type+status filtering'

      # PostgreSQL full-text search and JSON metadata indexes
      t.index "to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(metadata->>'summary', '') || ' ' || COALESCE(metadata->>'keywords', '') || ' ' || COALESCE(metadata->>'description', ''))", 
              using: :gin, 
              name: 'index_ragdoll_documents_on_fulltext_search',
              comment: 'Full-text search across title and metadata fields'
      
      t.index "(metadata->>'document_type')", name: 'index_ragdoll_documents_on_metadata_type'
      t.index "(metadata->>'classification')", name: 'index_ragdoll_documents_on_metadata_classification'
    end

    # === Text Contents Table ===
    create_table :ragdoll_text_contents,
                 comment: 'Text content storage for polymorphic embedding architecture' do |t|
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents },
                              comment: 'Reference to parent document'
      t.text :content, null: false, comment: 'Raw text content for embedding generation'
      t.string :embedding_model, null: false, comment: 'Embedding model to use for this text content'
      t.integer :chunk_size, default: 1000, comment: 'Text chunk size for embedding generation'
      t.integer :overlap, default: 200, comment: 'Overlap between chunks in characters'
      t.json :metadata, default: {}, comment: 'Additional metadata for text processing'
      t.timestamps null: false, comment: 'Standard creation and update timestamps'

      # Indexes (document_id index is automatically created by t.references)
      t.index :embedding_model, comment: 'Index for filtering by embedding model'
      t.index "to_tsvector('english', content)", 
              using: :gin, 
              name: 'index_ragdoll_text_contents_on_fulltext_search',
              comment: 'Full-text search index for text content'
    end

    # === Image Contents Table ===
    create_table :ragdoll_image_contents,
                 comment: 'Image content storage for polymorphic embedding architecture' do |t|
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents },
                              comment: 'Reference to parent document'
      t.string :embedding_model, null: false, comment: 'Embedding model to use for this image content (e.g., CLIP)'
      t.text :description, comment: 'Text description of image content for embedding'
      t.text :alt_text, comment: 'Alternative text for accessibility and search'
      t.json :metadata, default: {}, comment: 'Additional metadata including dimensions, processing info'
      t.text :image_data, comment: 'Shrine image attachment data (JSON)'
      t.timestamps null: false, comment: 'Standard creation and update timestamps'

      # Indexes (document_id index is automatically created by t.references)
      t.index :embedding_model, comment: 'Index for filtering by embedding model'
      t.index "to_tsvector('english', COALESCE(description, '') || ' ' || COALESCE(alt_text, ''))", 
              using: :gin, 
              name: 'index_ragdoll_image_contents_on_fulltext_search',
              comment: 'Full-text search index for image descriptions and alt text'
    end

    # === Audio Contents Table ===
    create_table :ragdoll_audio_contents,
                 comment: 'Audio content storage for polymorphic embedding architecture' do |t|
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents },
                              comment: 'Reference to parent document'
      t.string :embedding_model, null: false, comment: 'Embedding model to use for this audio content (e.g., Whisper)'
      t.text :transcript, comment: 'Text transcript of audio content for embedding'
      t.float :duration, comment: 'Duration of audio in seconds'
      t.integer :sample_rate, comment: 'Audio sample rate in Hz'
      t.json :metadata, default: {}, comment: 'Additional metadata including file info, processing parameters'
      t.text :audio_data, comment: 'Shrine audio attachment data (JSON)'
      t.timestamps null: false, comment: 'Standard creation and update timestamps'

      # Indexes (document_id index is automatically created by t.references)
      t.index :embedding_model, comment: 'Index for filtering by embedding model'
      t.index :duration, comment: 'Index for filtering by audio duration'
      t.index "to_tsvector('english', COALESCE(transcript, ''))", 
              using: :gin, 
              name: 'index_ragdoll_audio_contents_on_fulltext_search',
              comment: 'Full-text search index for audio transcripts'
    end

    # === Embeddings Table (Polymorphic) ===
    create_table :ragdoll_embeddings,
                 comment: 'Polymorphic vector embeddings storage for semantic similarity search' do |t|
      # Polymorphic association to embeddable content
      t.references :embeddable, polymorphic: true, null: false,
                                comment: 'Polymorphic reference to embeddable content (text, image, audio)'

      # Embedding content and vector data
      t.text :content, null: false, comment: 'Original text content that was embedded, typically a document chunk'
      t.vector :embedding_vector, limit: 1536, null: false,
                                  comment: 'Vector embedding using pgvector for optimal similarity search performance'

      # Embedding metadata
      t.string :embedding_model, null: false, comment: 'Embedding model identifier, critical for query compatibility'
      t.integer :chunk_index, null: false, comment: 'Chunk index for ordering embeddings within the embeddable content'

      # Usage analytics
      t.integer :usage_count, default: 0, comment: 'Number of times used in similarity searches, for caching optimization'
      t.datetime :returned_at, comment: 'Timestamp of most recent usage, for recency-based ranking and cache management'

      # Additional metadata
      t.json :metadata, default: {}, comment: 'Flexible JSON storage for embedding metadata, processing parameters, custom attributes'

      # Standard timestamps
      t.timestamps null: false, comment: 'Standard creation and update timestamps for lifecycle tracking'

      # Primary lookup indexes
      t.index [:embeddable_type, :embeddable_id], comment: 'Index for finding embeddings by embeddable content'
      t.index :embedding_model, comment: 'Index for filtering by embedding model'
      t.index %i[embedding_model usage_count], comment: 'Composite index for model-specific usage ranking'
      t.index :returned_at, comment: 'Index for recency-based queries and cache management'
      t.index :usage_count, comment: 'Index for popularity-based ranking and optimization'
      t.index %i[embeddable_type embeddable_id chunk_index],
              name: 'index_ragdoll_embeddings_on_embeddable_chunk',
              comment: 'Composite index for ordered content chunks within embeddable content', unique: true
      
      # pgvector similarity search index
      t.index :embedding_vector,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              name: 'index_ragdoll_embeddings_on_embedding_vector_cosine',
              comment: 'IVFFlat index for fast cosine similarity search using pgvector'
    end
  end

  def down
    drop_table :ragdoll_embeddings
    drop_table :ragdoll_audio_contents
    drop_table :ragdoll_image_contents
    drop_table :ragdoll_text_contents
    drop_table :ragdoll_documents
  end
end