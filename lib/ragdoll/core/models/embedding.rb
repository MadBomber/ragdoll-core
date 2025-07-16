# frozen_string_literal: true

require 'active_record'
require 'neighbor'

# == Schema Information
#
# Table name: ragdoll_embeddings
#
#  id               :integer          not null, primary key
#  embeddable_type  :string           not null
#  embeddable_id    :integer          not null
#  content          :text             not null
#  embedding_vector :vector           not null
#  embedding_model  :string           not null
#  chunk_index      :integer          not null
#  usage_count      :integer          default(0)
#  returned_at      :datetime
#  metadata         :json             default({})
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_ragdoll_embeddings_on_embeddable_type_and_embeddable_id (embeddable_type,embeddable_id)
#  index_ragdoll_embeddings_on_embedding_model                   (embedding_model)
#  index_ragdoll_embeddings_on_embedding_vector_cosine           (embedding_vector) USING ivfflat
#  index_ragdoll_embeddings_on_embeddable_chunk                  (embeddable_type,embeddable_id,chunk_index) UNIQUE
#  index_ragdoll_embeddings_on_usage_count                       (usage_count)
#  index_ragdoll_embeddings_on_returned_at                       (returned_at)
#

module Ragdoll
  module Core
    module Models
      class Embedding < ActiveRecord::Base
        self.table_name = 'ragdoll_embeddings'
        
        # No longer need workaround - using embedding_model column name

        # Use pgvector for vector similarity search
        has_neighbors :embedding_vector

        belongs_to :embeddable, polymorphic: true

        validates :embeddable_id, presence: true
        validates :embeddable_type, presence: true
        validates :chunk_index, presence: true, uniqueness: { scope: [:embeddable_id, :embeddable_type] }
        validates :embedding_vector, presence: true
        validates :content, presence: true
        validates :embedding_model, presence: true

        scope :by_model, ->(model) { where(embedding_model: model) }
        scope :recent, -> { order(created_at: :desc) }
        scope :frequently_used, -> { where('usage_count > 0').order(usage_count: :desc) }
        scope :by_chunk_order, -> { order(:chunk_index) }
        scope :by_embeddable_type, ->(type) { where(embeddable_type: type) }
        scope :text_embeddings, -> { where(embeddable_type: 'Ragdoll::Core::Models::TextContent') }
        scope :image_embeddings, -> { where(embeddable_type: 'Ragdoll::Core::Models::ImageContent') }
        scope :audio_embeddings, -> { where(embeddable_type: 'Ragdoll::Core::Models::AudioContent') }

        # JSON columns are handled natively by PostgreSQL - no serialization needed

        # Callback for vector column updates (no-op for pgvector)
        before_save :update_vector_columns

        def embedding_dimensions
          embedding_vector&.length || 0
        end


        def mark_as_used!
          increment!(:usage_count)
          update!(returned_at: Time.current)
        end




        # PostgreSQL pgvector similarity search using neighbor gem
        def self.search_similar(query_embedding, limit: 10, threshold: 0.7, filters: {})
          # Apply filters
          scope = all
          scope = scope.where(embeddable_id: filters[:embeddable_id]) if filters[:embeddable_id]
          scope = scope.where(embeddable_type: filters[:embeddable_type]) if filters[:embeddable_type]
          scope = scope.where(embedding_model: filters[:embedding_model]) if filters[:embedding_model]

          # Use pgvector for similarity search
          search_with_pgvector(query_embedding, scope, limit, threshold)
        end


        # Fast search using pgvector with neighbor gem
        def self.search_with_pgvector(query_embedding, scope, limit, threshold)
          # Use pgvector for similarity search
          neighbor_results = scope
                             .includes(:embeddable)
                             .nearest_neighbors(:embedding_vector, query_embedding, distance: 'cosine')
                             .limit(limit * 2) # Get more to filter by threshold

          results = []
          neighbor_results.each do |embedding|
            # Calculate cosine similarity (neighbor returns distance, we want similarity)
            similarity = 1.0 - embedding.neighbor_distance
            next if similarity < threshold

            usage_score = calculate_usage_score(embedding)
            combined_score = similarity + usage_score

            results << build_result_hash(embedding, query_embedding, similarity, usage_score, combined_score)
          end

          # Sort by combined score and limit
          results = results.sort_by { |r| -r[:combined_score] }.take(limit)
          mark_embeddings_as_used(results)
          results
        end



        private



        # Calculate usage score for ranking
        def self.calculate_usage_score(embedding)
          usage_score = 0.0
          if embedding.returned_at && embedding.usage_count > 0
            frequency_weight = 0.7
            recency_weight = 0.3

            frequency_score = [Math.log(embedding.usage_count + 1) / Math.log(100), 1.0].min
            days_since_use = (Time.current - embedding.returned_at) / 1.day
            recency_score = Math.exp(-days_since_use / 30)

            usage_score = frequency_weight * frequency_score + recency_weight * recency_score
          end
          usage_score
        end


        # Build standardized result hash
        def self.build_result_hash(embedding, query_embedding, similarity, usage_score, combined_score)
          {
            embedding_id: embedding.id.to_s,
            embeddable_id: embedding.embeddable_id.to_s,
            embeddable_type: embedding.embeddable_type,
            document_id: embedding.embeddable&.document_id&.to_s || 'Unknown',
            document_title: embedding.embeddable&.document&.title || 'Unknown',
            document_location: embedding.embeddable&.document&.location || 'Unknown',
            content: embedding.content,
            similarity: similarity,
            distance: 1.0 - similarity,
            chunk_index: embedding.chunk_index,
            metadata: embedding.metadata || {},
            embedding_dimensions: query_embedding.length,
            embedding_model: embedding.embedding_model,
            usage_count: embedding.usage_count || 0,
            returned_at: embedding.returned_at,
            usage_score: usage_score,
            combined_score: combined_score
          }
        end


        # Mark embeddings as used for analytics
        def self.mark_embeddings_as_used(results)
          return if results.empty?

          embedding_ids = results.map { |r| r[:embedding_id] }
          where(id: embedding_ids).update_all(
            usage_count: arel_table[:usage_count] + 1,
            returned_at: Time.current
          )
        end


        # Callback to update vector columns when embedding_vector changes
        def update_vector_columns
          # No additional processing needed for pgvector
        end


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
