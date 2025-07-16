# frozen_string_literal: true

module Ragdoll
  module Core
    class SearchEngine
      def initialize(embedding_service)
        @embedding_service = embedding_service
      end


      def search_documents(query, options = {})
        limit = options[:limit] || 10
        threshold = options[:threshold] || 0.7
        filters = options[:filters] || {}

        # Generate embedding for the query
        query_embedding = @embedding_service.generate_embedding(query)
        return [] if query_embedding.nil?

        # Search using ActiveRecord models
        Models::Embedding.search_similar(query_embedding,
                                         limit: limit,
                                         threshold: threshold,
                                         filters: filters)
      end


      def search_similar_content(query_or_embedding, options = {})
        limit = options[:limit] || 10
        threshold = options[:threshold] || 0.7
        filters = options[:filters] || {}

        if query_or_embedding.is_a?(Array)
          # It's already an embedding
          query_embedding = query_or_embedding
        else
          # It's a query string, generate embedding
          query_embedding = @embedding_service.generate_embedding(query_or_embedding)
          return [] if query_embedding.nil?
        end

        # Search using ActiveRecord models
        Models::Embedding.search_similar(query_embedding,
                                         limit: limit,
                                         threshold: threshold,
                                         filters: filters)
      end


      def add_document(location, content, metadata = {})
        document = Models::Document.create!(
          location: location,
          title: metadata[:title] || metadata['title'] || extract_title_from_location(location),
          document_type: metadata[:document_type] || metadata['document_type'] || 'text',
          metadata: metadata.is_a?(Hash) ? metadata : {},
          status: 'pending'
        )

        # Set content using the model's setter to trigger TextContent creation
        document.content = content if content.present?

        document.id.to_s
      end


      def get_document(id)
        document = Models::Document.find_by(id: id)
        document&.to_hash
      end


      def update_document(id, **updates)
        document = Models::Document.find_by(id: id)
        return nil unless document

        # Only update allowed fields
        allowed_updates = updates.slice(:title, :metadata, :status, :document_type)
        document.update!(allowed_updates) if allowed_updates.any?

        document.to_hash
      end


      def delete_document(id)
        document = Models::Document.find_by(id: id)
        return nil unless document

        document.destroy!
        true
      end


      def list_documents(options = {})
        limit = options[:limit] || 100
        offset = options[:offset] || 0

        Models::Document.offset(offset).limit(limit).recent.map(&:to_hash)
      end


      def get_document_stats
        Models::Document.stats
      end


      def add_embedding(document_id, chunk_index, embedding_vector, metadata = {})
        Models::Embedding.create!(
          document_id: document_id,
          chunk_index: chunk_index,
          embedding_vector: embedding_vector,
          content: metadata[:content] || '',
          embedding_model: metadata[:embedding_model] || metadata[:model_name] || 'unknown',
          metadata: metadata.except(:content, :embedding_model, :model_name)
        ).id.to_s
      end

      private

      def extract_title_from_location(location)
        File.basename(location, File.extname(location))
      end
    end
  end
end
