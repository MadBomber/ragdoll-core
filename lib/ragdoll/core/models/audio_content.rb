# frozen_string_literal: true

require 'active_record'
require 'active_storage'

# == Schema Information
#
# Table name: ragdoll_audio_contents
#
#  id           :integer          not null, primary key
#  document_id  :integer          not null
#  model_name   :string           not null
#  transcript   :text
#  duration     :float
#  sample_rate  :integer
#  metadata     :json             default({})
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_ragdoll_audio_contents_on_document_id  (document_id)
#  index_ragdoll_audio_contents_on_model_name   (model_name)
#
# Foreign Keys
#
#  fk_ragdoll_audio_contents_document_id  (document_id => ragdoll_documents.id)
#
# ActiveStorage Attachments
#
#  audio: Single audio attachment per audio content
#

module Ragdoll
  module Core
    module Models
      class AudioContent < ActiveRecord::Base
        self.table_name = 'ragdoll_audio_contents'

        belongs_to :document,
                   class_name: 'Ragdoll::Core::Models::Document',
                   foreign_key: 'document_id'

        has_many :embeddings,
                 as: :embeddable,
                 class_name: 'Ragdoll::Core::Models::Embedding',
                 dependent: :destroy

        # ActiveStorage audio attachment
        has_one_attached :audio

        validates :model_name, presence: true
        validate :audio_attached_or_transcript_present
        validates :duration, numericality: { greater_than: 0 }, allow_nil: true
        validates :sample_rate, numericality: { greater_than: 0 }, allow_nil: true

        # Serialize metadata as JSON
        serialize :metadata, type: Hash

        scope :by_model, ->(model) { where(model_name: model) }
        scope :recent, -> { order(created_at: :desc) }
        scope :with_audio, -> { joins(:audio_attachment) }
        scope :with_transcripts, -> { where.not(transcript: [nil, '']) }
        scope :by_duration, ->(min_duration, max_duration = nil) do
          scope = where('duration >= ?', min_duration)
          scope = scope.where('duration <= ?', max_duration) if max_duration
          scope
        end

        def embedding_count
          embeddings.count
        end

        # Audio-specific helper methods
        def audio_attached?
          respond_to?(:audio) && audio.attached?
        rescue NoMethodError
          false
        end

        def audio_size
          audio_attached? ? audio.byte_size : 0
        end

        def audio_content_type
          audio_attached? ? audio.content_type : nil
        end

        def audio_filename
          audio_attached? ? audio.filename.to_s : nil
        end

        def duration_formatted
          return 'Unknown' unless duration

          minutes = (duration / 60).floor
          seconds = (duration % 60).round
          "#{minutes}:#{seconds.to_s.rjust(2, '0')}"
        end

        # Content for embedding generation
        def embeddable_content
          transcript.presence || 'Audio content without transcript'
        end

        def generate_embeddings!
          return if embeddable_content.blank?

          # Clear existing embeddings
          embeddings.destroy_all

          # For audio, we might want to:
          # 1. Generate embeddings from transcript chunks
          # 2. Generate audio feature embeddings from raw audio
          # 3. Combine both for multi-modal search

          content = embeddable_content

          # Simple approach: embed the full transcript as one chunk
          # More sophisticated: chunk by time segments, sentences, etc.
          embeddings.create!(
            content: content,
            chunk_index: 0,
            model_name: model_name,
            metadata: {
              audio_filename: audio_filename,
              audio_content_type: audio_content_type,
              audio_size: audio_size,
              duration: duration,
              sample_rate: sample_rate,
              has_transcript: transcript.present?,
              transcript_word_count: transcript&.split&.length || 0
            }
          )
        end

        # Audio-specific search methods
        def self.search_content(query)
          where(
            "to_tsvector('english', COALESCE(transcript, '')) @@ plainto_tsquery('english', ?)",
            query
          )
        end

        def self.stats
          {
            total_audio_contents: count,
            by_model: group(:model_name).count,
            total_embeddings: joins(:embeddings).count,
            with_audio: with_audio.count,
            with_transcripts: with_transcripts.count,
            total_duration: sum(:duration),
            average_duration: average(:duration),
            average_audio_size: joins(:audio_attachment).average('active_storage_blobs.byte_size')
          }
        end

        private

        def audio_attached_or_transcript_present
          return if audio_attached? || transcript.present?

          errors.add(:base, 'Must have either an attached audio file or transcript')
        end
      end
    end
  end
end