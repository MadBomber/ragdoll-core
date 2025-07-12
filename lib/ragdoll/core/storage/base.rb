# frozen_string_literal: true

module Ragdoll
  module Core
    module Storage
      class Base
        def add_document(location, content, metadata = {})
          raise NotImplementedError, "Subclasses must implement #add_document"
        end
        
        def get_document(id)
          raise NotImplementedError, "Subclasses must implement #get_document"
        end
        
        def update_document(id, **updates)
          raise NotImplementedError, "Subclasses must implement #update_document"
        end
        
        def delete_document(id)
          raise NotImplementedError, "Subclasses must implement #delete_document"
        end
        
        def list_documents(options = {})
          raise NotImplementedError, "Subclasses must implement #list_documents"
        end
        
        def search_documents(query, options = {})
          raise NotImplementedError, "Subclasses must implement #search_documents"
        end
        
        def add_embedding(document_id, chunk_index, embedding, metadata = {})
          raise NotImplementedError, "Subclasses must implement #add_embedding"
        end
        
        def search_similar_embeddings(query_embedding, options = {})
          raise NotImplementedError, "Subclasses must implement #search_similar_embeddings"
        end

        def get_document_stats
          raise NotImplementedError, "Subclasses must implement #get_document_stats"
        end

        private

        def generate_id
          SecureRandom.uuid
        end

        def cosine_similarity(embedding1, embedding2)
          return 0.0 if embedding1.nil? || embedding2.nil?
          return 0.0 if embedding1.length != embedding2.length

          dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
          magnitude1 = Math.sqrt(embedding1.sum { |a| a * a })
          magnitude2 = Math.sqrt(embedding2.sum { |a| a * a })

          return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0

          dot_product / (magnitude1 * magnitude2)
        end
      end
    end
  end
end