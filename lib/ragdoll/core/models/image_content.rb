# frozen_string_literal: true

require 'active_record'

# == Schema Information
#
# Table name: ragdoll_image_contents
#
#  id          :integer          not null, primary key
#  document_id :integer          not null
#  embedding_model :string           not null
#  description :text
#  alt_text    :text
#  metadata    :json             default({})
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_ragdoll_image_contents_on_document_id  (document_id)
#  index_ragdoll_image_contents_on_embedding_model (embedding_model)
#
# Foreign Keys
#
#  fk_ragdoll_image_contents_document_id  (document_id => ragdoll_documents.id)
#
# Shrine Attachments
#
#  image_data: Shrine attachment data (JSON column)
#

module Ragdoll
  module Core
    module Models
      class ImageContent < ActiveRecord::Base
        self.table_name = 'ragdoll_image_contents'
        
        # No longer need workaround - using embedding_model column name

        belongs_to :document,
                   class_name: 'Ragdoll::Core::Models::Document',
                   foreign_key: 'document_id'

        has_many :embeddings,
                 as: :embeddable,
                 class_name: 'Ragdoll::Core::Models::Embedding',
                 dependent: :destroy

        # Shrine image attachment
        include ImageUploader::Attachment(:image)

        validates :embedding_model, presence: true
        validate :image_attached_or_description_present

        # JSON columns are handled natively by PostgreSQL - no serialization needed

        scope :by_model, ->(model) { where(embedding_model: model) }
        scope :recent, -> { order(created_at: :desc) }
        scope :with_images, -> { where.not(image_data: nil) }
        scope :with_descriptions, -> { where.not(description: [nil, '']) }

        def embedding_count
          embeddings.count
        end

        # Image-specific helper methods
        def image_attached?
          respond_to?(:image) && image.attached?
        rescue NoMethodError
          false
        end

        def image_size
          image_attached? ? image.byte_size : 0
        end

        def image_content_type
          image_attached? ? image.content_type : nil
        end

        def image_filename
          image_attached? ? image.filename.to_s : nil
        end

        def image_dimensions
          return nil unless image_attached?

          metadata['width'] && metadata['height'] ? 
            { width: metadata['width'], height: metadata['height'] } : nil
        end

        # Content for embedding generation
        def embeddable_content
          content_parts = []
          content_parts << alt_text if alt_text.present?
          content_parts << description if description.present?
          content_parts.join(' ')
        end

        def generate_embeddings!
          # Clear existing embeddings
          embeddings.destroy_all

          # Generate embedding for the image
          # This would typically involve:
          # 1. Image preprocessing (resizing, normalization)
          # 2. Running through vision model (CLIP, etc.)
          # 3. Optionally combining with text description

          content = embeddable_content
          if content.present?
            embeddings.create!(
              content: content,
              chunk_index: 0,
              embedding_model: embedding_model,
              metadata: {
                image_filename: image_filename,
                image_content_type: image_content_type,
                image_size: image_size,
                dimensions: image_dimensions,
                has_alt_text: alt_text.present?,
                has_description: description.present?
              }
            )
          end
        end

        # Image-specific search methods
        def self.search_content(query)
          where(
            "to_tsvector('english', COALESCE(description, '') || ' ' || COALESCE(alt_text, '')) @@ plainto_tsquery('english', ?)",
            query
          )
        end

        def self.stats
          {
            total_image_contents: count,
            by_model: group(:embedding_model).count,
            total_embeddings: joins(:embeddings).count,
            with_images: with_images.count,
            with_descriptions: with_descriptions.count,
            average_image_size: joins(:image_attachment).average('active_storage_blobs.byte_size')
          }
        end

        private

        def image_attached_or_description_present
          return if image_attached? || description.present? || alt_text.present?

          errors.add(:base, 'Must have either an attached image or description/alt_text')
        end
      end
    end
  end
end