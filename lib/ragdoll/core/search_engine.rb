# frozen_string_literal: true

module Ragdoll
  module Core
    class SearchEngine
      def initialize(storage_backend, embedding_service)
        @storage = storage_backend
        @embedding_service = embedding_service
      end

      def search_documents(query, options = {})
        limit = options[:limit] || 10
        threshold = options[:threshold] || 0.7
        filters = options[:filters] || {}

        # Generate embedding for the query
        query_embedding = @embedding_service.generate_embedding(query)
        return [] if query_embedding.nil?

        # Search using the storage backend
        @storage.search_similar_embeddings(query_embedding, 
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

        # Search using the storage backend
        @storage.search_similar_embeddings(query_embedding, 
                                          limit: limit, 
                                          threshold: threshold, 
                                          filters: filters)
      end

      def add_document(location, content, metadata = {})
        @storage.add_document(location, content, metadata)
      end

      def get_document(id)
        @storage.get_document(id)
      end

      def update_document(id, **updates)
        @storage.update_document(id, **updates) if @storage.respond_to?(:update_document)
      end

      def delete_document(id)
        @storage.delete_document(id) if @storage.respond_to?(:delete_document)
      end

      def list_documents(options = {})
        @storage.list_documents(options) if @storage.respond_to?(:list_documents)
      end

      def get_document_stats
        @storage.get_document_stats if @storage.respond_to?(:get_document_stats)
      end
    end
  end
end