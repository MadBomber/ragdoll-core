# frozen_string_literal: true

require 'active_record'

# == Schema Information
#
# Table name: ragdoll_embeddings
#
#  id               :integer          not null, primary key
#  document_id      :integer          not null
#  chunk_index      :integer          not null
#  embedding_vector :text             not null
#  content          :text             not null
#  model_name       :string           not null
#  metadata         :json             default({})
#  usage_count      :integer          default(0)
#  returned_at      :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_ragdoll_embeddings_on_document_id                (document_id)
#  index_ragdoll_embeddings_on_chunk_index                (chunk_index)
#  index_ragdoll_embeddings_on_model_name                 (model_name)
#  index_ragdoll_embeddings_on_usage_count                (usage_count)
#  index_ragdoll_embeddings_on_returned_at                (returned_at)
#  index_ragdoll_embeddings_on_document_id_and_chunk_index (document_id,chunk_index) UNIQUE
#  index_ragdoll_embeddings_on_created_at                 (created_at)
#
# Foreign Keys
#
#  fk_ragdoll_embeddings_document_id  (document_id => ragdoll_documents.id)
#

module Ragdoll
  module Core
    module Models
      class Embedding < ActiveRecord::Base
        self.table_name = 'ragdoll_embeddings'
        
        belongs_to :document, 
                   class_name: 'Ragdoll::Core::Models::Document',
                   foreign_key: 'document_id'
        
        validates :document_id, presence: true
        validates :chunk_index, presence: true, uniqueness: { scope: :document_id }
        validates :embedding_vector, presence: true
        validates :content, presence: true
        validates :model_name, presence: true
        
        scope :by_model, ->(model) { where(model_name: model) }
        scope :recent, -> { order(created_at: :desc) }
        scope :frequently_used, -> { where('usage_count > 0').order(usage_count: :desc) }
        
        # Serialize embedding vector as JSON
        serialize :embedding_vector, Array
        serialize :metadata, Hash
        
        def embedding_dimensions
          embedding_vector&.length || 0
        end
        
        def mark_as_used!
          increment!(:usage_count)
          update!(returned_at: Time.current)
        end
        
        def to_hash
          {
            id: id.to_s,
            document_id: document_id.to_s,
            document_title: document&.title || 'Unknown',
            document_location: document&.location || 'Unknown',
            content: content,
            chunk_index: chunk_index,
            embedding_vector: embedding_vector,
            embedding_dimensions: embedding_dimensions,
            model_name: model_name,
            metadata: metadata || {},
            usage_count: usage_count || 0,
            returned_at: returned_at,
            created_at: created_at
          }
        end
        
        # Search similar embeddings using cosine similarity
        def self.search_similar(query_embedding, limit: 10, threshold: 0.7, filters: {})
          # Apply filters
          scope = all
          scope = scope.where(document_id: filters[:document_id]) if filters[:document_id]
          scope = scope.where(model_name: filters[:model_name]) if filters[:model_name]
          
          # Get all embeddings and calculate similarity in Ruby
          # Note: For better performance, consider using a vector database or PostgreSQL with pgvector
          results = []
          
          scope.includes(:document).find_each do |embedding|
            similarity = cosine_similarity(query_embedding, embedding.embedding_vector)
            next if similarity < threshold
            
            # Calculate usage score
            usage_score = 0.0
            if embedding.returned_at && embedding.usage_count > 0
              frequency_weight = 0.7
              recency_weight = 0.3
              
              frequency_score = [Math.log(embedding.usage_count + 1) / Math.log(100), 1.0].min
              days_since_use = (Time.current - embedding.returned_at) / 1.day
              recency_score = Math.exp(-days_since_use / 30)
              
              usage_score = frequency_weight * frequency_score + recency_weight * recency_score
            end
            
            combined_score = similarity + usage_score
            
            results << {
              embedding_id: embedding.id.to_s,
              document_id: embedding.document_id.to_s,
              document_title: embedding.document&.title || 'Unknown',
              document_location: embedding.document&.location || 'Unknown',
              content: embedding.content,
              similarity: similarity,
              distance: 1.0 - similarity,
              chunk_index: embedding.chunk_index,
              metadata: embedding.metadata || {},
              embedding_dimensions: query_embedding.length,
              model_name: embedding.model_name,
              usage_count: embedding.usage_count || 0,
              returned_at: embedding.returned_at,
              usage_score: usage_score,
              combined_score: combined_score
            }
          end
          
          # Sort by combined score and limit results
          results = results.sort_by { |r| -r[:combined_score] }.take(limit)
          
          # Mark embeddings as used
          embedding_ids = results.map { |r| r[:embedding_id] }
          where(id: embedding_ids).update_all(
            usage_count: arel_table[:usage_count] + 1,
            returned_at: Time.current
          ) if embedding_ids.any?
          
          results
        end
        
        private
        
        def self.cosine_similarity(vec1, vec2)
          return 0.0 if vec1.nil? || vec2.nil? || vec1.length != vec2.length
          
          dot_product = vec1.zip(vec2).sum { |a, b| a * b }
          magnitude1 = Math.sqrt(vec1.sum { |a| a * a })
          magnitude2 = Math.sqrt(vec2.sum { |a| a * a })
          
          return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0
          
          dot_product / (magnitude1 * magnitude2)
        end
      end
    end
  end
end