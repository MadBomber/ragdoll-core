# frozen_string_literal: true

require 'active_record'

# == Schema Information
#
# Table name: ragdoll_text_contents
#
#  id          :integer          not null, primary key
#  document_id :integer          not null
#  content     :text             not null
#  model_name  :string           not null
#  chunk_size  :integer          default(1000)
#  overlap     :integer          default(200)
#  metadata    :json             default({})
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_ragdoll_text_contents_on_document_id  (document_id)
#  index_ragdoll_text_contents_on_model_name   (model_name)
#
# Foreign Keys
#
#  fk_ragdoll_text_contents_document_id  (document_id => ragdoll_documents.id)
#

module Ragdoll
  module Core
    module Models
      class TextContent < ActiveRecord::Base
        self.table_name = 'ragdoll_text_contents'
        
        # No longer need workaround - using embedding_model column name

        belongs_to :document,
                   class_name: 'Ragdoll::Core::Models::Document',
                   foreign_key: 'document_id'

        has_many :embeddings,
                 as: :embeddable,
                 class_name: 'Ragdoll::Core::Models::Embedding',
                 dependent: :destroy

        validates :content, presence: true
        validates :embedding_model, presence: true
        validates :chunk_size, presence: true, numericality: { greater_than: 0 }
        validates :overlap, presence: true, numericality: { greater_than_or_equal_to: 0 }

        # JSON columns are handled natively by PostgreSQL - no serialization needed

        scope :by_model, ->(model) { where(embedding_model: model) }
        scope :recent, -> { order(created_at: :desc) }

        def word_count
          content.split.length
        end

        def character_count
          content.length
        end

        def embedding_count
          embeddings.count
        end

        # Text-specific processing methods
        def chunks
          return [] if content.blank?

          chunks = []
          start_pos = 0

          while start_pos < content.length
            end_pos = [start_pos + chunk_size, content.length].min
            
            # Try to break at word boundary if not at end
            if end_pos < content.length
              last_space = content.rindex(' ', end_pos)
              end_pos = last_space if last_space && last_space > start_pos
            end

            chunk_content = content[start_pos...end_pos].strip
            chunks << {
              content: chunk_content,
              start_position: start_pos,
              end_position: end_pos,
              chunk_index: chunks.length
            } if chunk_content.present?

            break if end_pos >= content.length
            start_pos = [end_pos - overlap, start_pos + 1].max
          end

          chunks
        end

        def generate_embeddings!
          return if content.blank?

          # Clear existing embeddings
          embeddings.destroy_all

          # Generate embeddings for each chunk
          chunks.each do |chunk_data|
            embeddings.create!(
              content: chunk_data[:content],
              chunk_index: chunk_data[:chunk_index],
              embedding_model: embedding_model,
              metadata: {
                start_position: chunk_data[:start_position],
                end_position: chunk_data[:end_position],
                word_count: chunk_data[:content].split.length,
                character_count: chunk_data[:content].length
              }
            )
          end
        end

        # Text-specific search methods
        def self.search_content(query)
          where(
            "to_tsvector('english', content) @@ plainto_tsquery('english', ?)",
            query
          )
        end

        def self.stats
          {
            total_text_contents: count,
            by_model: group(:embedding_model).count,
            total_embeddings: joins(:embeddings).count,
            average_word_count: average('LENGTH(content) - LENGTH(REPLACE(content, \' \', \'\')) + 1'),
            average_chunk_size: average(:chunk_size)
          }
        end
      end
    end
  end
end