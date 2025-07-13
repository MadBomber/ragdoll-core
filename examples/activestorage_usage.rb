#!/usr/bin/env ruby

# Example demonstrating ActiveStorage integration with ragdoll-core
# This example shows how to work with file attachments

require 'bundler/setup'
require_relative '../lib/ragdoll-core'

# Configure ragdoll-core
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'sqlite3',
    database: File.join(Dir.home, '.ragdoll', 'ragdoll_example.sqlite3'),
    auto_migrate: true
  }
end

# Initialize the database
Ragdoll::Core::Database.setup

puts "=== ActiveStorage Integration Example ==="

# Example 1: Create document from file path
puts "\n1. Creating document from file path..."
begin
  # This would attach the file and extract content automatically
  # document = Ragdoll::Core::DocumentProcessor.create_document_from_file(
  #   '/path/to/document.pdf',
  #   title: 'Sample PDF Document'
  # )
  # puts "Document created with file attachment: #{document.file_attached?}"
  puts "Skipped - requires actual file path"
rescue => e
  puts "Error: #{e.message}"
end

# Example 2: Create document manually and attach file later
puts "\n2. Creating document manually..."
document = Ragdoll::Core::Models::Document.create!(
  location: 'example.txt',
  title: 'Example Document',
  content: 'This is example content',
  document_type: 'text',
  status: 'processed'
)

puts "Document ID: #{document.id}"
puts "Has file attached: #{document.file_attached?}"
puts "Content: #{document.content[0..50]}..."

# Example 3: Document with file attachment (simulated)
puts "\n3. Working with file attachments..."
puts "File size: #{document.file_size} bytes"
puts "File content type: #{document.file_content_type || 'none'}"
puts "File filename: #{document.file_filename || 'none'}"

# Example 4: Using DocumentProcessor helper methods
puts "\n4. DocumentProcessor helper methods..."
puts "PDF content type: #{Ragdoll::Core::DocumentProcessor.determine_content_type('document.pdf')}"
puts "DOCX document type: #{Ragdoll::Core::DocumentProcessor.determine_document_type_from_content_type('application/vnd.openxmlformats-officedocument.wordprocessingml.document')}"

# Example 5: Document to_hash with file info
puts "\n5. Document hash representation..."
hash = document.to_hash
puts "Document hash keys: #{hash.keys}"
puts "File attached in hash: #{hash[:file_attached]}"

puts "\n=== ActiveStorage Integration Complete ==="
puts "Note: Full ActiveStorage functionality requires proper Rails/ActiveStorage setup"
puts "The document model gracefully handles cases where ActiveStorage is not available"