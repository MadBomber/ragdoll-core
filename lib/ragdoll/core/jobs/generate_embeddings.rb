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
          return if document.all_embeddings.exists?

          config = Ragdoll::Core.configuration
          embedding_service = EmbeddingService.new(config)

          # Use provided chunk settings or defaults from config
          chunk_size ||= config.chunk_size
          chunk_overlap ||= config.chunk_overlap

          # Process each text content record
          document.text_contents.each do |text_content|
            # Chunk the content
            chunks = TextChunker.chunk(
              text_content.content,
              chunk_size: chunk_size,
              chunk_overlap: chunk_overlap
            )

            # Generate embeddings for each chunk
            chunks.each_with_index do |chunk, index|
              embedding_vector = embedding_service.generate_embedding(chunk)
              next unless embedding_vector

              # Create embedding record with polymorphic association
              Models::Embedding.create!(
                embeddable: text_content,
                content: chunk,
                embedding_vector: embedding_vector,
                embedding_model: config.embedding_model,
                chunk_index: index,
                metadata: {
                  chunk_size: chunk_size,
                  chunk_overlap: chunk_overlap,
                  generated_at: Time.current
                }
              )
            end
          end

          # Update document status to processed
          document.update!(status: 'processed')
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
