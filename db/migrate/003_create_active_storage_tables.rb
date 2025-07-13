# frozen_string_literal: true

# Migration: Create ActiveStorage Tables
#
# This migration creates the standard ActiveStorage tables required for file
# attachment functionality in the Ragdoll system. These tables enable each
# document to have exactly one attached file (PDF, DOCX, text, etc.).
#
# == Table Purpose:
# ActiveStorage provides a clean abstraction for file attachments with support
# for multiple storage backends (local disk, cloud storage like S3, GCS, Azure).
# The Ragdoll system uses this for document file management and content extraction.
#
# == Ragdoll Integration:
# - Each Document has exactly one file attachment via has_one_attached :file
# - Files are automatically processed for content extraction upon attachment
# - Supports PDF, DOCX, text, HTML, and Markdown files
# - File metadata is stored for content type validation and processing
#
# == Storage Strategy:
# - active_storage_blobs: File metadata and storage information
# - active_storage_attachments: Polymorphic join table linking models to blobs
# - active_storage_variant_records: Image variant information (optional for docs)
#
class CreateActiveStorageTables < ActiveRecord::Migration[7.0]
  def change
    # === Blob Storage Table ===

    # Stores file metadata and storage backend information
    # Each blob represents one uploaded file with its content and metadata
    create_table :active_storage_blobs,
                 comment: 'File metadata and storage backend information for uploaded documents' do |t|
      # Unique identifier for this blob, used for storage backend file naming
      # Format: [random]/[random] to prevent enumeration and ensure uniqueness
      t.string :key, null: false,
                     comment: 'Unique storage identifier preventing enumeration, format: [random]/[random]'

      # Original filename as provided during upload
      # Preserved for display purposes and content type detection
      t.string :filename, null: false,
                          comment: 'Original filename from upload, used for display and content type detection'

      # MIME content type of the uploaded file
      # Used for content validation and processing strategy selection
      t.string :content_type,
               comment: 'MIME content type for validation and processing strategy (application/pdf, text/plain, etc.)'

      # File metadata as JSON - can include EXIF data, custom attributes, processing info
      # For documents: may include page count, author, creation date, word count, etc.
      t.text :metadata,
             comment: 'JSON metadata including document properties, processing info, and custom attributes'

      # Service name indicating which storage backend is used
      # Examples: 'local', 's3', 'gcs', 'azure' - determined by Rails configuration
      t.string :service_name, null: false,
                              comment: 'Storage backend identifier (local, s3, gcs, azure) from Rails configuration'

      # File size in bytes - used for validation, storage management, and display
      t.bigint :byte_size, null: false,
                           comment: 'File size in bytes for validation, storage management, and UI display'

      # SHA256 checksum of file content for integrity validation
      # Prevents corruption and enables deduplication if desired
      t.string :checksum, comment: 'SHA256 checksum for file integrity validation and optional deduplication'

      # Standard timestamp for file upload tracking
      t.datetime :created_at, null: false, comment: 'File upload timestamp for lifecycle tracking'

      # NOTE: Indexes created manually after table creation to avoid conflicts
    end

    # === Attachment Join Table ===

    # Polymorphic join table connecting any model to blob files
    # In Ragdoll: connects Document models to their attached files
    create_table :active_storage_attachments,
                 comment: 'Polymorphic join table connecting models to blob files, Documents to their attached files' do |t|
      # Attachment name/role - for Ragdoll documents this is typically 'file'
      # Allows models to have multiple named attachments (though Ragdoll uses only one)
      t.string :name, null: false, comment: 'Attachment role name, typically "file" for Ragdoll documents'

      # Polymorphic reference to the model that owns this attachment
      # For Ragdoll: record_type='Ragdoll::Core::Models::Document', record_id=document.id
      t.references :record, null: false, polymorphic: true, index: false,
                            comment: 'Polymorphic owner reference, Ragdoll documents use record_type=Document'

      # Reference to the actual file blob containing the content and metadata
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs },
                          comment: 'Reference to blob containing actual file content and metadata'

      # Standard timestamp for attachment lifecycle tracking
      t.datetime :created_at, null: false, comment: 'Attachment creation timestamp for lifecycle tracking'

      # NOTE: Indexes created manually after table creation to avoid conflicts
    end

    # === Variant Records Table ===

    # Stores information about image variants (thumbnails, resized versions)
    # Not heavily used in Ragdoll since we focus on documents, but required by ActiveStorage
    # Could be useful for document preview thumbnails if implemented
    create_table :active_storage_variant_records,
                 comment: 'Image variant metadata for thumbnails and resized versions, optional for document previews' do |t|
      # Reference to the source blob that this variant is derived from
      t.belongs_to :blob, null: false, index: false, foreign_key: { to_table: :active_storage_blobs },
                          comment: 'Source blob that this variant is derived from'

      # Serialized variation key describing the transformation applied
      # For documents: could describe thumbnail generation, page extraction, etc.
      t.string :variation_digest, null: false,
                                  comment: 'Serialized transformation key for thumbnail/preview generation'

      # NOTE: Indexes created manually after table creation to avoid conflicts
    end

    # === Manual Index Creation ===

    # ActiveStorage blob indexes
    unless index_exists?(
      :active_storage_blobs, [:key], unique: true
    )
      add_index :active_storage_blobs, [:key], unique: true,
                                               comment: 'Unique index on storage key for fast blob lookup'
    end

    # ActiveStorage attachment indexes
    unless index_exists?(
      :active_storage_attachments, %i[record_type record_id name
                                      blob_id], name: 'index_active_storage_attachments_uniqueness'
    )
      add_index :active_storage_attachments, %i[record_type record_id name blob_id],
                name: 'index_active_storage_attachments_uniqueness', unique: true,
                comment: 'Composite unique index ensuring one attachment per model+name combination'
    end

    unless index_exists?(
      :active_storage_attachments, [:blob_id]
    )
      add_index :active_storage_attachments, [:blob_id],
                comment: 'Index for finding all attachments using a specific blob (reverse lookup)'
    end

    unless index_exists?(
      :active_storage_attachments, %i[record_type record_id
                                      name], name: 'index_active_storage_attachments_on_record'
    )
      add_index :active_storage_attachments, %i[record_type record_id name],
                name: 'index_active_storage_attachments_on_record',
                comment: 'Optimized index for Ragdoll document file attachment lookups'
    end

    # ActiveStorage variant record indexes
    unless index_exists?(
      :active_storage_variant_records, %i[blob_id
                                          variation_digest], name: 'index_active_storage_variant_records_uniqueness'
    )
      add_index :active_storage_variant_records, %i[blob_id variation_digest],
                name: 'index_active_storage_variant_records_uniqueness', unique: true,
                comment: 'Composite unique index ensuring one variant per blob+transformation combination'
    end

    # === Database-Specific Optimizations ===

    case connection.adapter_name.downcase
    when 'postgresql'
      # Add GIN index for efficient JSON metadata queries if using PostgreSQL
      if column_exists?(:active_storage_blobs, :metadata)
        execute 'CREATE INDEX IF NOT EXISTS index_active_storage_blobs_on_metadata ON active_storage_blobs USING GIN (metadata jsonb_path_ops);'
      end
    when 'mysql2'
      # Add fulltext index for filename searches in MySQL
      add_index :active_storage_blobs, :filename, type: :fulltext,
                                                  name: 'index_active_storage_blobs_on_filename_fulltext'
    end
  end


  def down
    # Remove manual indexes
    remove_index :active_storage_blobs, [:key] if index_exists?(:active_storage_blobs, [:key])
    if index_exists?(
      :active_storage_attachments, %i[record_type record_id name
                                      blob_id], name: 'index_active_storage_attachments_uniqueness'
    )
      remove_index :active_storage_attachments,
                   name: 'index_active_storage_attachments_uniqueness'
    end
    remove_index :active_storage_attachments, [:blob_id] if index_exists?(:active_storage_attachments,
                                                                          [:blob_id])
    if index_exists?(
      :active_storage_attachments, %i[record_type record_id
                                      name], name: 'index_active_storage_attachments_on_record'
    )
      remove_index :active_storage_attachments,
                   name: 'index_active_storage_attachments_on_record'
    end
    if index_exists?(
      :active_storage_variant_records, %i[blob_id
                                          variation_digest], name: 'index_active_storage_variant_records_uniqueness'
    )
      remove_index :active_storage_variant_records,
                   name: 'index_active_storage_variant_records_uniqueness'
    end

    # Clean up database-specific optimizations
    case connection.adapter_name.downcase
    when 'postgresql'
      begin
        execute 'DROP INDEX IF EXISTS index_active_storage_blobs_on_metadata;'
      rescue StandardError
        nil
      end
    when 'mysql2'
      if index_exists?(
        :active_storage_blobs, :filename, name: 'index_active_storage_blobs_on_filename_fulltext'
      )
        remove_index :active_storage_blobs,
                     name: 'index_active_storage_blobs_on_filename_fulltext'
      end
    end

    # Drop tables in reverse dependency order
    drop_table :active_storage_variant_records
    drop_table :active_storage_attachments
    drop_table :active_storage_blobs
  end
end
