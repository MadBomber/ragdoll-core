# frozen_string_literal: true

require 'active_job'

module Ragdoll
  module Core
    module Jobs
      class GenerateEmbeddings < ActiveJob::Base
        queue_as :default

        def perform(document_id, chunk_size: nil, chunk_overlap: nil)
          document = Models::Document.find(document_id)
          return unless document.content.present?
          return if document.embeddings.exists?

          config = Ragdoll::Core.configuration
          embedding_service = EmbeddingService.new(config)
          search_engine = SearchEngine.new(embedding_service)

          # Use provided chunk settings or defaults from config
          chunk_size ||= config.chunk_size
          chunk_overlap ||= config.chunk_overlap

          # Chunk the content
          chunks = TextChunker.chunk(
            document.content,
            chunk_size: chunk_size,
            chunk_overlap: chunk_overlap
          )

          # Generate embeddings for each chunk
          chunks.each_with_index do |chunk, index|
            embedding = embedding_service.generate_embedding(chunk)
            next unless embedding

            search_engine.add_embedding(document.id, index, embedding, {
              content: chunk,
              model_name: config.embedding_model,
              chunk_size: chunk_size,
              chunk_overlap: chunk_overlap
            })
          end
        rescue ActiveRecord::RecordNotFound
          # Document was deleted, nothing to do
        rescue StandardError => e
          Rails.logger.error "Failed to generate embeddings for document #{document_id}: #{e.message}" if defined?(Rails)
          raise e
        end
      end
    end
  end
end
