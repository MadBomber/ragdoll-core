# frozen_string_literal: true

module Ragdoll
  module Core
    module Storage
      class ActiveRecordStorage < Base
        def initialize(config = {})
          @config = config
          # Expect ActiveRecord models to be provided in config
          @document_model = config[:document_model]
          @embedding_model = config[:embedding_model]
          
          unless @document_model && @embedding_model
            raise StorageError, "ActiveRecord storage requires :document_model and :embedding_model in config"
          end
        end

        def add_document(location, content, metadata = {})
          document = @document_model.create!(
            location: location,
            content: content,
            title: metadata[:title] || metadata['title'] || extract_title_from_location(location),
            metadata: metadata.is_a?(Hash) ? metadata : {},
            document_type: metadata[:document_type] || metadata['document_type'] || 'text',
            status: 'processed'
          )
          
          document.id.to_s
        end

        def get_document(id)
          document = @document_model.find_by(id: id)
          return nil unless document
          
          {
            id: document.id.to_s,
            location: document.location,
            content: document.content,
            metadata: document.metadata || {},
            status: document.status,
            created_at: document.created_at,
            updated_at: document.updated_at
          }
        end

        def update_document(id, **updates)
          document = @document_model.find_by(id: id)
          return nil unless document
          
          # Only update allowed fields
          allowed_fields = [:title, :metadata, :status, :content]
          update_params = updates.select { |k, v| allowed_fields.include?(k) }
          
          document.update!(update_params) if update_params.any?
          get_document(id)
        end

        def delete_document(id)
          document = @document_model.find_by(id: id)
          return nil unless document
          
          # Delete associated embeddings first
          @embedding_model.where(document_id: id).delete_all
          
          result = get_document(id)
          document.destroy!
          result
        end

        def list_documents(options = {})
          limit = options[:limit] || 100
          offset = options[:offset] || 0
          
          documents = @document_model.limit(limit).offset(offset).order(:created_at)
          
          documents.map do |doc|
            {
              id: doc.id.to_s,
              location: doc.location,
              title: doc.title,
              metadata: doc.metadata || {},
              document_type: doc.document_type,
              status: doc.status,
              created_at: doc.created_at,
              updated_at: doc.updated_at
            }
          end
        end

        def search_documents(query, options = {})
          limit = options[:limit] || 10
          
          # Simple text search on title and content
          documents = @document_model
            .where("title ILIKE ? OR content ILIKE ?", "%#{query}%", "%#{query}%")
            .limit(limit)
            .order(:created_at)
          
          documents.map do |doc|
            {
              id: doc.id.to_s,
              location: doc.location,
              title: doc.title,
              content: doc.content,
              metadata: doc.metadata || {},
              document_type: doc.document_type,
              status: doc.status
            }
          end
        end

        def add_embedding(document_id, chunk_index, embedding, metadata = {})
          embedding_record = @embedding_model.create!(
            document_id: document_id,
            chunk_index: chunk_index,
            embedding: embedding.to_json,
            content: metadata[:content] || metadata['content'] || '',
            metadata: metadata.is_a?(Hash) ? metadata : {},
            model_name: metadata[:model_name] || metadata['model_name'],
            usage_count: 0
          )
          
          embedding_record.id.to_s
        end

        def search_similar_embeddings(query_embedding, options = {})
          limit = options[:limit] || 10
          threshold = options[:threshold] || 0.7
          filters = options[:filters] || {}
          model_name = filters[:model_name]
          
          # Get embeddings with proper includes to avoid N+1 queries
          embeddings_query = @embedding_model.includes(:document).limit(1000)
          
          # Filter by model_name if specified
          if model_name.present?
            embeddings_query = embeddings_query.where(model_name: model_name)
          end
          
          # Filter by document_id if specified
          if filters[:document_id]
            embeddings_query = embeddings_query.where(document_id: filters[:document_id])
          end
          
          embeddings = embeddings_query.to_a
          results = []
          
          embeddings.each do |embedding_record|
            begin
              # Parse the stored JSON embedding
              stored_embedding = JSON.parse(embedding_record.embedding)
              next unless stored_embedding.is_a?(Array) && stored_embedding.length == query_embedding.length
              
              # Calculate cosine similarity
              similarity = cosine_similarity(query_embedding, stored_embedding)
              next if similarity < threshold
              
              # Calculate usage score if needed
              usage_score = 0.0
              if options.fetch(:use_usage_ranking, true) && embedding_record.returned_at
                frequency_weight = options.fetch(:frequency_weight, 0.7)
                recency_weight = options.fetch(:recency_weight, 0.3)
                
                frequency_score = [Math.log(embedding_record.usage_count + 1) / Math.log(100), 1.0].min
                days_since_use = (Time.current - embedding_record.returned_at) / 1.day
                recency_score = Math.exp(-days_since_use / 30)
                
                usage_score = frequency_weight * frequency_score + recency_weight * recency_score
              end
              
              combined_score = options.fetch(:similarity_weight, 1.0) * similarity + usage_score
              
              results << {
                embedding_id: embedding_record.id.to_s,
                document_id: embedding_record.document_id.to_s,
                document_title: embedding_record.document&.title || 'Unknown',
                document_location: embedding_record.document&.location || 'Unknown',
                content: embedding_record.content,
                similarity: similarity,
                distance: 1.0 - similarity,
                chunk_index: embedding_record.chunk_index,
                metadata: embedding_record.metadata || {},
                embedding_dimensions: query_embedding.length,
                model_name: embedding_record.model_name,
                usage_count: embedding_record.usage_count || 0,
                returned_at: embedding_record.returned_at,
                usage_score: usage_score,
                combined_score: combined_score
              }
            rescue JSON::ParserError => e
              # Log warning but continue processing
              Rails.logger.warn "Failed to parse embedding JSON for embedding #{embedding_record.id}: #{e.message}" if defined?(Rails)
              next
            end
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
            total_documents: @document_model.count,
            total_embeddings: @embedding_model.count,
            storage_type: 'activerecord',
            database_adapter: @document_model.connection.adapter_name
          }
        end

        private

        def record_usage_for_embeddings(embedding_ids)
          return if embedding_ids.empty?
          
          # Use batch update for better performance
          @embedding_model.where(id: embedding_ids).update_all(
            usage_count: @embedding_model.arel_table[:usage_count] + 1,
            returned_at: Time.current
          )
        rescue => e
          Rails.logger.warn "Failed to record embedding usage: #{e.message}" if defined?(Rails)
          # Don't fail the search if usage recording fails
        end

        def extract_title_from_location(location)
          return location unless location.is_a?(String)
          
          # If it's a file path, extract the filename without extension
          if location.include?('/')
            filename = File.basename(location)
            File.basename(filename, File.extname(filename))
          else
            location
          end
        end
      end
    end
  end
end