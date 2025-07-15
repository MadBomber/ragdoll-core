# frozen_string_literal: true

# Migration: Create ActiveStorage Tables
#
# This migration creates the ActiveStorage tables required for file attachments
# in the Ragdoll system. ActiveStorage is used for storing document files, 
# images, and audio files.

class CreateActiveStorageTables < ActiveRecord::Migration[7.0]
  def change
    # Primary blob storage table
    create_table :active_storage_blobs, id: :primary_key do |t|
      t.string   :key,          null: false
      t.string   :filename,     null: false
      t.string   :content_type
      t.text     :metadata
      t.string   :service_name, null: false
      t.bigint   :byte_size,    null: false
      t.string   :checksum

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false
      else
        t.datetime :created_at, null: false
      end

      t.index [ :key ], unique: true
    end

    # Attachments join table
    create_table :active_storage_attachments, id: :primary_key do |t|
      t.string     :name,     null: false
      t.references :record,   null: false, polymorphic: true, index: false
      t.references :blob,     null: false

      if connection.supports_datetime_with_precision?
        t.datetime :created_at, precision: 6, null: false
      else
        t.datetime :created_at, null: false
      end

      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end

    # Variant records table  
    create_table :active_storage_variant_records, id: :primary_key do |t|
      t.belongs_to :blob, null: false, index: false
      t.string :variation_digest, null: false

      t.index %i[ blob_id variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
      t.foreign_key :active_storage_blobs, column: :blob_id
    end
  end

  def down
    drop_table :active_storage_variant_records
    drop_table :active_storage_attachments
    drop_table :active_storage_blobs
  end
end