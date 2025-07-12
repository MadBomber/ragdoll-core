# frozen_string_literal: true

require 'json'
require 'securerandom'

module Ragdoll
  module Core
    module Storage
      class MemoryStorage < Base
        def initialize(config = {})
          @config = config
          @documents = {}
          @embeddings = {}
          @next_document_id = 1
          @next_embedding_id = 1
        end

        def add_document(location, content, metadata = {})
          doc_id = @next_document_id.to_s
          @next_document_id += 1

          document = {
            id: doc_id,
            location: location,
            content: content,
            metadata: metadata,
            status: 'processed',
            created_at: Time.now,
            updated_at: Time.now
          }

          @documents[doc_id] = document
          doc_id
        end

        def get_document(id)
          @documents[id.to_s]
        end

        def update_document(id, **updates)
          doc = @documents[id.to_s]
          return nil unless doc

          updates.each do |key, value|
            doc[key] = value if doc.has_key?(key)
          end
          doc[:updated_at] = Time.now

          doc
        end

        def delete_document(id)
          doc = @documents.delete(id.to_s)
          # Also remove associated embeddings
          @embeddings.delete_if { |_, embedding| embedding[:document_id] == id.to_s }
          doc
        end

        def list_documents(options = {})
          limit = options[:limit] || 100
          offset = options[:offset] || 0
          
          docs = @documents.values
          docs = docs.drop(offset).take(limit)
          docs
        end

        def search_documents(query, options = {})
          # Simple text search for documents
          results = @documents.values.select do |doc|
            doc[:content].downcase.include?(query.downcase) ||
            doc[:location].downcase.include?(query.downcase)
          end

          limit = options[:limit] || 10
          results.take(limit)
        end

        def add_embedding(document_id, chunk_index, embedding, metadata = {})
          embedding_id = @next_embedding_id.to_s
          @next_embedding_id += 1

          embedding_record = {
            id: embedding_id,
            document_id: document_id.to_s,
            chunk_index: chunk_index,
            embedding: embedding,
            content: metadata[:content] || '',
            metadata: metadata,
            model_name: metadata[:model_name],
            usage_count: 0,
            returned_at: nil,
            created_at: Time.now
          }

          @embeddings[embedding_id] = embedding_record
          embedding_id
        end

        def search_similar_embeddings(query_embedding, options = {})
          limit = options[:limit] || 10
          threshold = options[:threshold] || 0.7
          filters = options[:filters] || {}

          results = []

          @embeddings.each do |embedding_id, embedding_record|
            # Apply filters if provided
            next if filters[:document_id] && embedding_record[:document_id] != filters[:document_id].to_s
            next if filters[:model_name] && embedding_record[:model_name] != filters[:model_name]

            similarity = cosine_similarity(query_embedding, embedding_record[:embedding])
            next if similarity < threshold

            # Calculate usage score if needed
            usage_score = 0.0
            if options.fetch(:use_usage_ranking, true) && embedding_record[:returned_at]
              frequency_weight = options.fetch(:frequency_weight, 0.7)
              recency_weight = options.fetch(:recency_weight, 0.3)
              
              frequency_score = [Math.log(embedding_record[:usage_count] + 1) / Math.log(100), 1.0].min
              days_since_use = (Time.now - embedding_record[:returned_at]) / (24 * 60 * 60)
              recency_score = Math.exp(-days_since_use / 30)
              
              usage_score = frequency_weight * frequency_score + recency_weight * recency_score
            end

            combined_score = options.fetch(:similarity_weight, 1.0) * similarity + usage_score

            document = @documents[embedding_record[:document_id]]
            
            results << {
              embedding_id: embedding_id,
              document_id: embedding_record[:document_id],
              document_title: document ? (document[:metadata][:title] || document[:location]) : 'Unknown',
              document_location: document ? document[:location] : 'Unknown',
              content: embedding_record[:content],
              similarity: similarity,
              distance: 1.0 - similarity,
              chunk_index: embedding_record[:chunk_index],
              metadata: embedding_record[:metadata] || {},
              embedding_dimensions: query_embedding.length,
              model_name: embedding_record[:model_name],
              usage_count: embedding_record[:usage_count] || 0,
              returned_at: embedding_record[:returned_at],
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
          {
            total_documents: @documents.length,
            total_embeddings: @embeddings.length,
            storage_type: 'memory'
          }
        end

        private

        def record_usage_for_embeddings(embedding_ids)
          embedding_ids.each do |embedding_id|
            embedding = @embeddings[embedding_id]
            next unless embedding

            embedding[:usage_count] = (embedding[:usage_count] || 0) + 1
            embedding[:returned_at] = Time.now
          end
        end
      end
    end
  end
end