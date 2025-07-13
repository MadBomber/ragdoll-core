# frozen_string_literal: true

# Migration: Create Ragdoll Embeddings Table
#
# This migration creates the embeddings table for storing vector embeddings
# generated from document content. The table supports multiple embedding models,
# usage tracking, and similarity search capabilities.
#
# == Table Purpose:
# The embeddings table stores vector representations of document chunks for
# semantic similarity search in the RAG system. Each embedding is linked to
# a document and contains the vector data along with metadata about the
# embedding model used and usage statistics.
#
# == Vector Storage Strategy:
# - JSON format for cross-database compatibility (default)
# - PostgreSQL: Optional native vector column with pgvector extension
# - SQLite: Optional sqlite3-vec extension support for performance
# - MySQL: Optional binary storage for space efficiency
#
# == Usage Tracking:
# The table includes comprehensive usage analytics to track which embeddings
# are most frequently accessed, enabling intelligent caching and optimization
# of the RAG system's performance.
#
class CreateRagdollEmbeddings < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_embeddings, comment: 'Vector embeddings storage for semantic similarity search with usage tracking and model metadata' do |t|
      # === Document Association ===
      
      # Foreign key reference to the source document
      # Each embedding belongs to exactly one document, but documents can have multiple embeddings
      # (e.g., different chunks, different embedding models, re-processing)
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents }, 
                   comment: 'Reference to source document, each embedding belongs to one document'
      
      # === Embedding Content ===
      
      # The actual text content that was embedded
      # This is typically a chunk of the original document content
      # Stored for reference and debugging purposes
      t.text :content, null: false, comment: 'Original text content that was embedded, typically a document chunk'
      
      # Vector embedding data stored as JSON array for cross-database compatibility
      # Contains the numerical vector representation (typically 1536-3072 dimensions)
      # JSON format ensures compatibility across SQLite, PostgreSQL, and MySQL
      t.json :embedding_vector, null: false, comment: 'Vector embedding as JSON array, cross-database compatible numerical representation'
      
      # === Embedding Metadata ===
      
      # Name/identifier of the embedding model used (e.g., 'text-embedding-3-small')
      # Critical for compatibility when querying - embeddings from different models
      # cannot be directly compared and must use the same model for similarity search
      t.string :model_name, null: false, comment: 'Embedding model identifier (e.g. text-embedding-3-small), critical for query compatibility'
      
      # Dimensionality of the embedding vector (e.g., 1536, 3072)
      # Used for validation and optimization purposes
      # Must match the expected dimensions for the specified model
      t.integer :dimensions, null: false, comment: 'Vector dimensionality (e.g. 1536, 3072), must match model specifications'
      
      # === Content Positioning ===
      
      # Starting character position of this embedding's content within the source document
      # Used for text chunking and precise content location for result highlighting
      t.integer :start_position, default: 0, comment: 'Starting character position within source document for chunking and highlighting'
      
      # Ending character position of this embedding's content within the source document
      # Used with start_position to define the exact text span this embedding represents
      t.integer :end_position, default: 0, comment: 'Ending character position within source document, defines exact text span'
      
      # === Usage Analytics ===
      
      # Counter for how many times this embedding has been used in similarity searches
      # Higher counts indicate more valuable/relevant embeddings for caching optimization
      t.integer :usage_count, default: 0, comment: 'Number of times used in similarity searches, for caching optimization'
      
      # Timestamp of the most recent usage in a similarity search
      # Used for recency-based ranking and cache eviction strategies
      t.datetime :last_used_at, comment: 'Timestamp of most recent usage, for recency-based ranking and cache management'
      
      # === Quality Metrics ===
      
      # Optional similarity score or confidence rating for this embedding
      # Can be used to track embedding quality or relevance scores
      t.float :similarity_score, comment: 'Optional similarity or confidence score for embedding quality tracking'
      
      # === Additional Metadata ===
      
      # Flexible JSON storage for embedding-specific metadata
      # Can store tokenization info, processing parameters, custom attributes, etc.
      t.json :metadata, default: {}, comment: 'Flexible JSON storage for embedding metadata, processing parameters, custom attributes'
      
      # === Timestamps ===
      
      # Standard Rails timestamps for record lifecycle tracking
      t.timestamps null: false, comment: 'Standard creation and update timestamps for lifecycle tracking'
      
      # Note: Database indexes are created automatically by ActiveRecord for foreign keys
    end
    
    # === Manual Index Creation ===
    
    # Primary lookup indexes (created separately to avoid conflicts)
    add_index :ragdoll_embeddings, :document_id, comment: 'Index for finding embeddings by document' unless index_exists?(:ragdoll_embeddings, :document_id)
    add_index :ragdoll_embeddings, :model_name, comment: 'Index for filtering by embedding model' unless index_exists?(:ragdoll_embeddings, :model_name)
    add_index :ragdoll_embeddings, [:model_name, :usage_count], comment: 'Composite index for model-specific usage ranking' unless index_exists?(:ragdoll_embeddings, [:model_name, :usage_count])
    add_index :ragdoll_embeddings, [:model_name, :dimensions], comment: 'Composite index for model and dimension validation' unless index_exists?(:ragdoll_embeddings, [:model_name, :dimensions])
    add_index :ragdoll_embeddings, :last_used_at, comment: 'Index for recency-based queries and cache management' unless index_exists?(:ragdoll_embeddings, :last_used_at)
    add_index :ragdoll_embeddings, :usage_count, comment: 'Index for popularity-based ranking and optimization' unless index_exists?(:ragdoll_embeddings, :usage_count)
    add_index :ragdoll_embeddings, [:document_id, :start_position], comment: 'Composite index for ordered content chunks within documents' unless index_exists?(:ragdoll_embeddings, [:document_id, :start_position])
    
    # === Database-Specific Vector Optimizations ===
    
    case connection.adapter_name.downcase
    when 'postgresql'
      # PostgreSQL with pgvector extension support
      begin
        # Enable the vector extension if available
        enable_extension "vector" if respond_to?(:enable_extension)
        
        # Add native vector column for optimal similarity search performance
        # This provides hardware-accelerated vector operations and indexing
        add_column :ragdoll_embeddings, :embedding_vector_native, :vector, limit: 3072,
                   comment: 'Native PostgreSQL vector column for hardware-accelerated similarity search'
        
        # Create IVFFlat index for fast approximate nearest neighbor search
        # Uses cosine distance which is standard for embedding similarity
        add_index :ragdoll_embeddings, :embedding_vector_native, 
                  using: :ivfflat, 
                  opclass: :vector_cosine_ops,
                  name: 'index_ragdoll_embeddings_on_vector_cosine',
                  comment: 'IVFFlat index for fast cosine similarity search'
      rescue
        # puts "PostgreSQL vector extension not available, using JSON storage: #{e.message}" if ActiveRecord::Migration.verbose
      end
      
    when 'sqlite'
      # SQLite with optional sqlite3-vec extension support
      begin
        # Attempt to load the vec0 extension for native vector operations
        execute "SELECT load_extension('vec0')"
        
        # Create virtual table for vector similarity search
        # Provides native vector operations when sqlite3-vec is available
        execute <<-SQL
          CREATE VIRTUAL TABLE IF NOT EXISTS ragdoll_embeddings_vec
          USING vec0(
            embedding_id INTEGER PRIMARY KEY,
            embedding_vector FLOAT[3072]
          );
        SQL
        
        # === Vector Table Synchronization Triggers ===
        
        # Trigger to sync vector table on INSERT
        execute <<-SQL
          CREATE TRIGGER IF NOT EXISTS ragdoll_embeddings_vec_insert 
          AFTER INSERT ON ragdoll_embeddings 
          WHEN NEW.embedding_vector IS NOT NULL
          BEGIN
            INSERT INTO ragdoll_embeddings_vec(embedding_id, embedding_vector)
            VALUES (NEW.id, NEW.embedding_vector);
          END;
        SQL
        
        # Trigger to sync vector table on UPDATE
        execute <<-SQL
          CREATE TRIGGER IF NOT EXISTS ragdoll_embeddings_vec_update 
          AFTER UPDATE ON ragdoll_embeddings 
          WHEN NEW.embedding_vector IS NOT NULL
          BEGIN
            DELETE FROM ragdoll_embeddings_vec WHERE embedding_id = OLD.id;
            INSERT INTO ragdoll_embeddings_vec(embedding_id, embedding_vector)
            VALUES (NEW.id, NEW.embedding_vector);
          END;
        SQL
        
        # Trigger to sync vector table on DELETE
        execute <<-SQL
          CREATE TRIGGER IF NOT EXISTS ragdoll_embeddings_vec_delete 
          AFTER DELETE ON ragdoll_embeddings 
          BEGIN
            DELETE FROM ragdoll_embeddings_vec WHERE embedding_id = OLD.id;
          END;
        SQL
        
        # puts "SQLite vec0 extension loaded successfully - vector operations available" if ActiveRecord::Migration.verbose
      rescue
        # puts "SQLite vec0 extension not available, using JSON storage: #{e.message}" if ActiveRecord::Migration.verbose
      end
      
    when 'mysql2'
      # MySQL optimizations for vector storage
      # Add binary column for more efficient storage of large vectors
      add_column :ragdoll_embeddings, :embedding_vector_binary, :binary,
                 comment: 'Binary storage for space-efficient vector storage in MySQL'
      
      # Track vector dimensions for binary storage validation
      add_column :ragdoll_embeddings, :vector_dimensions, :integer, default: 0,
                 comment: 'Vector dimension count for binary storage validation'
    end
  end
  
  def down
    # Remove manual indexes
    remove_index :ragdoll_embeddings, :document_id if index_exists?(:ragdoll_embeddings, :document_id)
    remove_index :ragdoll_embeddings, :model_name if index_exists?(:ragdoll_embeddings, :model_name)
    remove_index :ragdoll_embeddings, [:model_name, :usage_count] if index_exists?(:ragdoll_embeddings, [:model_name, :usage_count])
    remove_index :ragdoll_embeddings, [:model_name, :dimensions] if index_exists?(:ragdoll_embeddings, [:model_name, :dimensions])
    remove_index :ragdoll_embeddings, :last_used_at if index_exists?(:ragdoll_embeddings, :last_used_at)
    remove_index :ragdoll_embeddings, :usage_count if index_exists?(:ragdoll_embeddings, :usage_count)
    remove_index :ragdoll_embeddings, [:document_id, :start_position] if index_exists?(:ragdoll_embeddings, [:document_id, :start_position])
    
    # Clean up database-specific extensions
    case connection.adapter_name.downcase
    when 'postgresql'
      if column_exists?(:ragdoll_embeddings, :embedding_vector_native)
        remove_index :ragdoll_embeddings, name: 'index_ragdoll_embeddings_on_vector_cosine' if index_exists?(:ragdoll_embeddings, :embedding_vector_native, name: 'index_ragdoll_embeddings_on_vector_cosine')
        remove_column :ragdoll_embeddings, :embedding_vector_native
      end
    when 'sqlite'
      # Clean up vec0 extension artifacts
      execute "DROP TRIGGER IF EXISTS ragdoll_embeddings_vec_insert;" rescue nil
      execute "DROP TRIGGER IF EXISTS ragdoll_embeddings_vec_update;" rescue nil
      execute "DROP TRIGGER IF EXISTS ragdoll_embeddings_vec_delete;" rescue nil
      execute "DROP TABLE IF EXISTS ragdoll_embeddings_vec;" rescue nil
    when 'mysql2'
      remove_column :ragdoll_embeddings, :embedding_vector_binary if column_exists?(:ragdoll_embeddings, :embedding_vector_binary)
      remove_column :ragdoll_embeddings, :vector_dimensions if column_exists?(:ragdoll_embeddings, :vector_dimensions)
    end
    
    drop_table :ragdoll_embeddings
  end
end