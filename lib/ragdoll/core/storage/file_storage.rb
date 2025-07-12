# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'securerandom'

module Ragdoll
  module Core
    module Storage
      class FileStorage < Base
        def initialize(config = {})
          @config = config
          @directory = config[:directory] || File.expand_path("~/.ragdoll")
          @documents_file = File.join(@directory, 'documents.json')
          @embeddings_file = File.join(@directory, 'embeddings.json')
          
          ensure_directory_exists
          ensure_files_exist
        end

        def add_document(location, content, metadata = {})
          documents = load_documents
          doc_id = generate_id

          document = {
            'id' => doc_id,
            'location' => location,
            'content' => content,
            'metadata' => metadata,
            'status' => 'processed',
            'created_at' => Time.now.iso8601,
            'updated_at' => Time.now.iso8601
          }

          documents[doc_id] = document
          save_documents(documents)
          doc_id
        end

        def get_document(id)
          documents = load_documents
          documents[id.to_s]
        end

        def update_document(id, **updates)
          documents = load_documents
          doc = documents[id.to_s]
          return nil unless doc

          updates.each do |key, value|
            string_key = key.to_s
            doc[string_key] = value if doc.has_key?(string_key)
          end
          doc['updated_at'] = Time.now.iso8601

          save_documents(documents)
          doc
        end

        def delete_document(id)
          documents = load_documents
          embeddings = load_embeddings
          
          doc = documents.delete(id.to_s)
          
          # Remove associated embeddings
          embeddings.delete_if { |_, embedding| embedding['document_id'] == id.to_s }
          
          save_documents(documents)
          save_embeddings(embeddings)
          doc
        end

        def list_documents(options = {})
          documents = load_documents
          limit = options[:limit] || 100
          offset = options[:offset] || 0
          
          docs = documents.values
          docs = docs.drop(offset).take(limit)
          docs
        end

        def search_documents(query, options = {})
          documents = load_documents
          
          # Simple text search for documents
          results = documents.values.select do |doc|
            doc['content'].downcase.include?(query.downcase) ||
            doc['location'].downcase.include?(query.downcase)
          end

          limit = options[:limit] || 10
          results.take(limit)
        end

        def add_embedding(document_id, chunk_index, embedding, metadata = {})
          embeddings = load_embeddings
          embedding_id = generate_id

          embedding_record = {
            'id' => embedding_id,
            'document_id' => document_id.to_s,
            'chunk_index' => chunk_index,
            'embedding' => embedding,
            'content' => metadata[:content] || metadata['content'] || '',
            'metadata' => metadata,
            'model_name' => metadata[:model_name] || metadata['model_name'],
            'usage_count' => 0,
            'returned_at' => nil,
            'created_at' => Time.now.iso8601
          }

          embeddings[embedding_id] = embedding_record
          save_embeddings(embeddings)
          embedding_id
        end

        def search_similar_embeddings(query_embedding, options = {})
          embeddings = load_embeddings
          documents = load_documents
          
          limit = options[:limit] || 10
          threshold = options[:threshold] || 0.7
          filters = options[:filters] || {}

          results = []

          embeddings.each do |embedding_id, embedding_record|
            # Apply filters if provided
            next if filters[:document_id] && embedding_record['document_id'] != filters[:document_id].to_s
            next if filters[:model_name] && embedding_record['model_name'] != filters[:model_name]

            similarity = cosine_similarity(query_embedding, embedding_record['embedding'])
            next if similarity < threshold

            # Calculate usage score if needed
            usage_score = 0.0
            if options.fetch(:use_usage_ranking, true) && embedding_record['returned_at']
              frequency_weight = options.fetch(:frequency_weight, 0.7)
              recency_weight = options.fetch(:recency_weight, 0.3)
              
              frequency_score = [Math.log(embedding_record['usage_count'] + 1) / Math.log(100), 1.0].min
              returned_at = Time.parse(embedding_record['returned_at'])
              days_since_use = (Time.now - returned_at) / (24 * 60 * 60)
              recency_score = Math.exp(-days_since_use / 30)
              
              usage_score = frequency_weight * frequency_score + recency_weight * recency_score
            end

            combined_score = options.fetch(:similarity_weight, 1.0) * similarity + usage_score

            document = documents[embedding_record['document_id']]
            
            results << {
              embedding_id: embedding_id,
              document_id: embedding_record['document_id'],
              document_title: document ? (document['metadata']['title'] || document['location']) : 'Unknown',
              document_location: document ? document['location'] : 'Unknown',
              content: embedding_record['content'],
              similarity: similarity,
              distance: 1.0 - similarity,
              chunk_index: embedding_record['chunk_index'],
              metadata: embedding_record['metadata'] || {},
              embedding_dimensions: query_embedding.length,
              model_name: embedding_record['model_name'],
              usage_count: embedding_record['usage_count'] || 0,
              returned_at: embedding_record['returned_at'],
              usage_score: usage_score,
              combined_score: combined_score
            }
          end

          # Sort by combined score and limit results
          results = results.sort_by { |r| -r[:combined_score] }.take(limit)
          
          # Record usage for returned embeddings
          embedding_ids = results.map { |r| r[:embedding_id] }
          record_usage_for_embeddings(embedding_ids) if embedding_ids.any?
          
          results
        end

        def get_document_stats
          documents = load_documents
          embeddings = load_embeddings
          
          {
            total_documents: documents.length,
            total_embeddings: embeddings.length,
            storage_type: 'file',
            storage_directory: @directory
          }
        end

        private

        def ensure_directory_exists
          FileUtils.mkdir_p(@directory) unless Dir.exist?(@directory)
        end

        def ensure_files_exist
          File.write(@documents_file, '{}') unless File.exist?(@documents_file)
          File.write(@embeddings_file, '{}') unless File.exist?(@embeddings_file)
        end

        def load_documents
          return {} unless File.exist?(@documents_file)
          JSON.parse(File.read(@documents_file))
        rescue JSON::ParserError
          {}
        end

        def save_documents(documents)
          File.write(@documents_file, JSON.pretty_generate(documents))
        end

        def load_embeddings
          return {} unless File.exist?(@embeddings_file)
          JSON.parse(File.read(@embeddings_file))
        rescue JSON::ParserError
          {}
        end

        def save_embeddings(embeddings)
          File.write(@embeddings_file, JSON.pretty_generate(embeddings))
        end

        def record_usage_for_embeddings(embedding_ids)
          embeddings = load_embeddings
          
          embedding_ids.each do |embedding_id|
            embedding = embeddings[embedding_id]
            next unless embedding

            embedding['usage_count'] = (embedding['usage_count'] || 0) + 1
            embedding['returned_at'] = Time.now.iso8601
          end
          
          save_embeddings(embeddings)
        end

        def generate_id
          SecureRandom.uuid
        end
      end
    end
  end
end