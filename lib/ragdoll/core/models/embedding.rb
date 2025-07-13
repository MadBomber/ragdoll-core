# frozen_string_literal: true

require 'active_record'
require 'neighbor'

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

        # Include neighbor for vector similarity search (check when connection is available)
        def self.setup_neighbor_search
          return unless ActiveRecord::Base.connected?
          return unless column_names.include?('embedding_vector_neighbor')

          has_neighbors :embedding_vector_neighbor
        end

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

        # Serialize embedding vector as JSON (backward compatibility)
        serialize :embedding_vector, type: Array
        serialize :metadata, type: Hash

        # Callbacks to keep vector columns in sync
        before_save :update_vector_columns

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


        # Enhanced search using neighbor gem for better performance
        def self.search_similar(query_embedding, limit: 10, threshold: 0.7, filters: {})
          # Apply filters
          scope = all
          scope = scope.where(document_id: filters[:document_id]) if filters[:document_id]
          scope = scope.where(model_name: filters[:model_name]) if filters[:model_name]

          # Choose the best search method based on database and available extensions
          case ActiveRecord::Base.connection.adapter_name.downcase
          when 'postgresql'
            if use_neighbor_search?
              search_with_neighbor(query_embedding, scope, limit, threshold)
            else
              search_with_ruby_cosine(query_embedding, scope, limit, threshold)
            end
          when 'sqlite'
            if sqlite_vec_available?
              search_with_sqlite_vec(query_embedding, scope, limit, threshold)
            else
              search_with_ruby_cosine(query_embedding, scope, limit, threshold)
            end
          else
            search_with_ruby_cosine(query_embedding, scope, limit, threshold)
          end
        end


        # Fast search using neighbor gem (PostgreSQL with pgvector)
        def self.search_with_neighbor(query_embedding, scope, limit, threshold)
          # Convert to the format neighbor expects
          neighbor_results = scope
                             .includes(:document)
                             .nearest_neighbors(:embedding_vector_neighbor, query_embedding, distance: 'cosine')
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


        # Fallback search using Ruby cosine similarity (SQLite, MySQL)
        def self.search_with_ruby_cosine(query_embedding, scope, limit, threshold)
          results = []

          scope.includes(:document).find_each do |embedding|
            similarity = cosine_similarity(query_embedding, embedding.embedding_vector)
            next if similarity < threshold

            usage_score = calculate_usage_score(embedding)
            combined_score = similarity + usage_score

            results << build_result_hash(embedding, query_embedding, similarity, usage_score, combined_score)
          end

          # Sort by combined score and limit results
          results = results.sort_by { |r| -r[:combined_score] }.take(limit)
          mark_embeddings_as_used(results)
          results
        end


        # SQLite vector search using sqlite3-vec extension
        def self.search_with_sqlite_vec(query_embedding, scope, limit, threshold)
          # Use sqlite3-vec for fast similarity search
          # Convert query embedding to the format expected by vec0
          query_str = query_embedding.map(&:to_f).join(',')

          # Perform KNN search using sqlite3-vec
          sql = <<-SQL
            SELECT#{' '}
              e.*,#{' '}
              vec_distance_cosine(v.embedding_vector, '[#{query_str}]') as distance
            FROM ragdoll_embeddings e
            JOIN ragdoll_embeddings_vec v ON e.id = v.embedding_id
            WHERE e.id IN (#{scope.select(:id).to_sql})
            ORDER BY distance ASC
            LIMIT #{limit * 2}
          SQL

          results = []
          connection.exec_query(sql).each do |row|
            distance = row['distance'].to_f
            similarity = 1.0 - distance # Convert distance to similarity
            next if similarity < threshold

            # Load the full embedding record
            embedding = scope.includes(:document).find(row['id'])

            usage_score = calculate_usage_score(embedding)
            combined_score = similarity + usage_score

            results << build_result_hash(embedding, query_embedding, similarity, usage_score, combined_score)
          end

          results = results.sort_by { |r| -r[:combined_score] }.take(limit)
          mark_embeddings_as_used(results)
          results
        end

        private

        # Check if PostgreSQL neighbor search is available
        def self.use_neighbor_search?
          return false unless ActiveRecord::Base.connected?

          ActiveRecord::Base.connection.adapter_name.downcase == 'postgresql' &&
            column_names.include?('embedding_vector_neighbor')
        end


        # Check if SQLite vec extension is available
        def self.sqlite_vec_available?
          return @sqlite_vec_available if defined?(@sqlite_vec_available)
          return false unless ActiveRecord::Base.connected?

          begin
            ActiveRecord::Base.connection.exec_query('SELECT vec_version()')
            @sqlite_vec_available = true
          rescue StandardError
            @sqlite_vec_available = false
          end
        end


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
          return unless embedding_vector.present?
          return unless ActiveRecord::Base.connected?

          case ActiveRecord::Base.connection.adapter_name.downcase
          when 'postgresql'
            if self.class.column_names.include?('embedding_vector_neighbor')
              self.embedding_vector_neighbor = embedding_vector
            end
          when 'sqlite'
            # SQLite vec table is updated via triggers
          when 'mysql2'
            if self.class.column_names.include?('embedding_vector_binary')
              self.embedding_vector_binary = pack_vector(embedding_vector)
              self.vector_dimensions = embedding_vector.length
            end
          end
        end


        # Pack vector for binary storage (MySQL)
        def pack_vector(vector)
          vector.pack('f*') # Pack as 32-bit floats
        end


        # Unpack vector from binary storage (MySQL)
        def self.unpack_vector(binary_data)
          binary_data.unpack('f*') # Unpack 32-bit floats
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
