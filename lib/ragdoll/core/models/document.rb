# frozen_string_literal: true

require 'active_record'
require 'active_storage'
require_relative '../metadata_schemas'

# == Schema Information
#
# Table name: ragdoll_documents
#
#  id            :integer          not null, primary key
#  location      :string           not null
#  content       :text             not null
#  title         :string           not null
#  document_type :string           default("text"), not null
#  metadata      :json             default({})
#  status        :string           default("pending"), not null
#  summary       :text             # Auto-generated summary for search
#  keywords      :text             # Extracted keywords for faceted search
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_ragdoll_documents_on_location       (location)
#  index_ragdoll_documents_on_title          (title)
#  index_ragdoll_documents_on_document_type  (document_type)
#  index_ragdoll_documents_on_status         (status)
#  index_ragdoll_documents_on_created_at     (created_at)
#
# ActiveStorage Attachments
#
#  file: Single file attachment per document (PDF, DOCX, text, etc.)
#
# Full-text Search
#
#  Uses summary and keywords fields for search, not raw content
#  Supports faceted search by keywords
#

module Ragdoll
  module Core
    module Models
      class Document < ActiveRecord::Base
        self.table_name = 'ragdoll_documents'

        # PostgreSQL full-text search on summary and keywords
        # Uses PostgreSQL's built-in full-text search capabilities

        # ActiveStorage file attachment (optional - only if ActiveStorage is properly set up)
        # Each document has exactly one file attachment
        has_one_attached :file

        # Multi-modal content relationships
        has_many :text_contents,
                 class_name: 'Ragdoll::Core::Models::TextContent',
                 foreign_key: 'document_id',
                 dependent: :destroy

        has_many :image_contents,
                 class_name: 'Ragdoll::Core::Models::ImageContent',
                 foreign_key: 'document_id',
                 dependent: :destroy

        has_many :audio_contents,
                 class_name: 'Ragdoll::Core::Models::AudioContent',
                 foreign_key: 'document_id',
                 dependent: :destroy

        # All embeddings across content types
        has_many :text_embeddings, through: :text_contents, source: :embeddings
        has_many :image_embeddings, through: :image_contents, source: :embeddings
        has_many :audio_embeddings, through: :audio_contents, source: :embeddings

        validates :location, presence: true
        validates :title, presence: true
        validates :document_type, presence: true, inclusion: { in: %w[text image audio pdf docx html markdown mixed] }
        validates :status, inclusion: { in: %w[pending processing processed error] }

        # Serialize JSON columns
        serialize :metadata, type: Hash
        serialize :file_metadata, type: Hash

        scope :processed, -> { where(status: 'processed') }
        scope :by_type, ->(type) { where(document_type: type) }
        scope :recent, -> { order(created_at: :desc) }
        scope :with_files, -> { joins(:file_attachment) }
        scope :without_files, lambda {
          left_joins(:file_attachment).where(active_storage_attachments: { id: nil })
        }

        # Callbacks to process files using background jobs
        after_commit :queue_text_extraction, on: %i[create update],
                                             if: :file_attached_and_content_empty?

        def processed?
          status == 'processed'
        end


        # Multi-modal content type detection
        def multi_modal?
          content_types.length > 1
        end

        def content_types
          types = []
          types << 'text' if text_contents.any?
          types << 'image' if image_contents.any?
          types << 'audio' if audio_contents.any?
          types
        end

        def primary_content_type
          return document_type if %w[text image audio].include?(document_type)
          return content_types.first if content_types.any?
          'text' # default
        end

        # Content statistics
        def total_word_count
          text_contents.sum(&:word_count)
        end

        def total_character_count
          text_contents.sum(&:character_count)
        end

        def total_embedding_count
          text_embeddings.count + image_embeddings.count + audio_embeddings.count
        end

        def embeddings_by_type
          {
            text: text_embeddings.count,
            image: image_embeddings.count,
            audio: audio_embeddings.count
          }
        end


        # Document metadata methods
        def has_summary?
          metadata['summary'].present?
        end

        def summary
          metadata['summary']
        end

        def summary=(value)
          self.metadata = metadata.merge('summary' => value)
        end

        def has_keywords?
          metadata['keywords'].present?
        end

        def keywords_array
          return [] unless metadata['keywords'].present?
          
          case metadata['keywords']
          when Array
            metadata['keywords']
          when String
            metadata['keywords'].split(',').map(&:strip).reject(&:empty?)
          else
            []
          end
        end

        def add_keyword(keyword)
          current_keywords = keywords_array
          return if current_keywords.include?(keyword.strip)

          current_keywords << keyword.strip
          self.metadata = metadata.merge('keywords' => current_keywords)
        end

        def remove_keyword(keyword)
          current_keywords = keywords_array
          current_keywords.delete(keyword.strip)
          self.metadata = metadata.merge('keywords' => current_keywords)
        end

        # Metadata accessors for common fields
        def description
          metadata['description']
        end

        def description=(value)
          self.metadata = metadata.merge('description' => value)
        end

        def classification
          metadata['classification']
        end

        def classification=(value)
          self.metadata = metadata.merge('classification' => value)
        end

        def tags
          metadata['tags'] || []
        end

        def tags=(value)
          self.metadata = metadata.merge('tags' => Array(value))
        end


        # File-related helper methods
        def file_attached?
          respond_to?(:file) && file.attached?
        rescue NoMethodError
          false
        end


        def file_size
          file_attached? ? file.byte_size : 0
        end


        def file_content_type
          file_attached? ? file.content_type : nil
        end


        def file_filename
          file_attached? ? file.filename.to_s : nil
        end


        # Content processing for multi-modal documents
        def process_content!
          return unless file_attached?

          case file_content_type
          when /^text\//
            process_as_text_content
          when /^image\//
            process_as_image_content
          when /^audio\//
            process_as_audio_content
          when 'application/pdf'
            process_pdf_content
          when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            process_docx_content
          else
            process_as_text_content # fallback
          end

          # Generate embeddings for all content
          generate_embeddings_for_all_content!
          
          # Generate structured metadata using LLM
          generate_metadata!
          
          update!(status: 'processed')
        end

        # Generate embeddings for all content types
        def generate_embeddings_for_all_content!
          text_contents.each(&:generate_embeddings!)
          image_contents.each(&:generate_embeddings!)
          audio_contents.each(&:generate_embeddings!)
        end
        
        # Generate structured metadata using LLM
        def generate_metadata!
          require_relative '../services/metadata_generator'
          
          generator = Services::MetadataGenerator.new
          generated_metadata = generator.generate_for_document(self)
          
          # Validate metadata against schema
          errors = MetadataSchemas.validate_metadata(document_type, generated_metadata)
          if errors.any?
            Rails.logger.warn "Metadata validation errors: #{errors.join(', ')}" if defined?(Rails)
            puts "Metadata validation errors: #{errors.join(', ')}"
          end
          
          # Merge with existing metadata (preserving user-set values)
          self.metadata = metadata.merge(generated_metadata)
          save!
        rescue StandardError => e
          Rails.logger.error "Metadata generation failed: #{e.message}" if defined?(Rails)
          puts "Metadata generation failed: #{e.message}"
        end




        # PostgreSQL full-text search on metadata fields
        def self.search_content(query, **options)
          return none if query.blank?

          # Use PostgreSQL's built-in full-text search across metadata fields
          where(
            "to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(metadata->>'summary', '') || ' ' || COALESCE(metadata->>'keywords', '') || ' ' || COALESCE(metadata->>'description', '')) @@ plainto_tsquery('english', ?)",
            query
          ).limit(options[:limit] || 20)
        end

        # Faceted search by metadata fields
        def self.faceted_search(query: nil, keywords: [], classification: nil, tags: [], **options)
          scope = all

          # Filter by keywords if provided
          if keywords.any?
            keywords.each do |keyword|
              scope = scope.where("metadata->>'keywords' ILIKE ?", "%#{keyword}%")
            end
          end

          # Filter by classification
          if classification.present?
            scope = scope.where("metadata->>'classification' = ?", classification)
          end

          # Filter by tags
          if tags.any?
            tags.each do |tag|
              scope = scope.where("metadata ? 'tags' AND metadata->'tags' @> ?", [tag].to_json)
            end
          end

          # Apply PostgreSQL full-text search if query provided
          if query.present?
            scope = scope.where(
              "to_tsvector('english', COALESCE(title, '') || ' ' || COALESCE(metadata->>'summary', '') || ' ' || COALESCE(metadata->>'keywords', '') || ' ' || COALESCE(metadata->>'description', '')) @@ plainto_tsquery('english', ?)",
              query
            )
          end

          scope.limit(options[:limit] || 20)
        end


        # Get all unique keywords from metadata
        def self.all_keywords
          keywords = []
          where("metadata ? 'keywords'").pluck(:metadata).each do |meta|
            case meta['keywords']
            when Array
              keywords.concat(meta['keywords'])
            when String
              keywords.concat(meta['keywords'].split(',').map(&:strip))
            end
          end
          keywords.uniq.sort
        end

        # Get all unique classifications
        def self.all_classifications
          where("metadata ? 'classification'").distinct.pluck("metadata->>'classification'").compact.sort
        end

        # Get all unique tags
        def self.all_tags
          tags = []
          where("metadata ? 'tags'").pluck(:metadata).each do |meta|
            tags.concat(Array(meta['tags']))
          end
          tags.uniq.sort
        end

        # Get keyword frequencies for faceted search
        def self.keyword_frequencies
          frequencies = Hash.new(0)
          where("metadata ? 'keywords'").pluck(:metadata).each do |meta|
            case meta['keywords']
            when Array
              meta['keywords'].each { |k| frequencies[k] += 1 }
            when String
              meta['keywords'].split(',').map(&:strip).each { |k| frequencies[k] += 1 }
            end
          end
          frequencies.sort_by { |_k, v| -v }.to_h
        end


        # Hybrid search combining semantic and PostgreSQL full-text search
        def self.hybrid_search(query, query_embedding: nil, **options)
          limit = options[:limit] || 20
          semantic_weight = options[:semantic_weight] || 0.7
          text_weight = options[:text_weight] || 0.3

          results = []

          # Get semantic search results if embedding provided
          if query_embedding
            semantic_results = embeddings_search(query_embedding, limit: limit)
            results.concat(semantic_results.map do |result|
              result.merge(
                search_type: 'semantic',
                weighted_score: result[:combined_score] * semantic_weight
              )
            end)
          end

          # Get PostgreSQL full-text search results
          text_results = search_content(query, limit: limit)
          text_results.each_with_index do |doc, index|
            score = (limit - index).to_f / limit * text_weight
            results << {
              document_id: doc.id.to_s,
              document_title: doc.title,
              document_location: doc.location,
              content: doc.content[0..500], # Preview
              search_type: 'full_text',
              weighted_score: score,
              document: doc
            }
          end

          # Combine and deduplicate by document_id
          combined = results.group_by { |r| r[:document_id] }
                            .map do |_doc_id, doc_results|
            best_result = doc_results.max_by { |r| r[:weighted_score] }
            total_score = doc_results.sum { |r| r[:weighted_score] }
            search_types = doc_results.map { |r| r[:search_type] }.uniq

            best_result.merge(
              combined_score: total_score,
              search_types: search_types
            )
          end

          combined.sort_by { |r| -r[:combined_score] }.take(limit)
        end


        # Get search data for indexing
        def search_data
          data = {
            title: title,
            document_type: document_type,
            location: location,
            status: status,
            total_word_count: total_word_count,
            total_character_count: total_character_count,
            total_embedding_count: total_embedding_count,
            content_types: content_types,
            multi_modal: multi_modal?
          }

          # Add document metadata
          data.merge!(metadata.transform_keys { |k| "metadata_#{k}" }) if metadata.present?
          
          # Add file metadata
          data.merge!(file_metadata.transform_keys { |k| "file_#{k}" }) if file_metadata.present?

          data
        end

        private


        def all_embeddings
          Ragdoll::Core::Models::Embedding.where(
            "(embeddable_type = 'Ragdoll::Core::Models::TextContent' AND embeddable_id IN (?)) OR " +
            "(embeddable_type = 'Ragdoll::Core::Models::ImageContent' AND embeddable_id IN (?)) OR " +
            "(embeddable_type = 'Ragdoll::Core::Models::AudioContent' AND embeddable_id IN (?))",
            text_contents.pluck(:id),
            image_contents.pluck(:id), 
            audio_contents.pluck(:id)
          )
        end

        def self.embeddings_search(query_embedding, **options)
          Ragdoll::Core::Models::Embedding.search_similar(query_embedding, **options)
        end


        # Multi-modal content processing methods
        def process_as_text_content
          extracted_text = extract_text_from_file
          return unless extracted_text.present?

          text_contents.create!(
            content: extracted_text,
            model_name: default_text_model,
            metadata: {
              extracted_from_file: true,
              file_type: file_content_type,
              extraction_method: 'file_processing'
            }
          )
        end

        def process_as_image_content
          image_contents.create!(
            model_name: default_image_model,
            description: extract_image_description,
            metadata: {
              file_type: file_content_type,
              dimensions: extract_image_dimensions
            }
          ).tap do |image_content|
            image_content.image.attach(file.blob)
          end
        end

        def process_as_audio_content
          audio_contents.create!(
            model_name: default_audio_model,
            transcript: extract_audio_transcript,
            duration: extract_audio_duration,
            sample_rate: extract_audio_sample_rate,
            metadata: {
              file_type: file_content_type
            }
          ).tap do |audio_content|
            audio_content.audio.attach(file.blob)
          end
        end

        def process_pdf_content
          extracted_text = extract_pdf_content
          return unless extracted_text.present?

          text_contents.create!(
            content: extracted_text,
            model_name: default_text_model,
            metadata: {
              extracted_from_pdf: true,
              extraction_method: 'pdf_reader'
            }
          )
        end

        def process_docx_content
          extracted_text = extract_docx_content
          return unless extracted_text.present?

          text_contents.create!(
            content: extracted_text,
            model_name: default_text_model,
            metadata: {
              extracted_from_docx: true,
              extraction_method: 'docx_parser'
            }
          )
        end


        def extract_text_from_file
          return nil unless file_attached?

          case file_content_type
          when 'application/pdf'
            extract_pdf_content
          when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            extract_docx_content
          when 'text/plain', 'text/html', 'text/markdown'
            extract_text_content
          end
        end


        def extract_pdf_content
          require 'pdf-reader'

          file.open do |tempfile|
            reader = PDF::Reader.new(tempfile.path)
            content = reader.pages.map(&:text).join("\n")

            # Cache the extracted content in file metadata
            file.metadata['extracted_content'] = content if content.present?

            content
          end
        rescue StandardError => e
          puts "PDF extraction failed: #{e.message}"
          nil
        end


        def extract_docx_content
          require 'docx'

          file.open do |tempfile|
            doc = Docx::Document.open(tempfile.path)
            content = doc.paragraphs.map(&:text).join("\n")

            # Cache the extracted content in file metadata
            file.metadata['extracted_content'] = content if content.present?

            content
          end
        rescue StandardError => e
          puts "DOCX extraction failed: #{e.message}"
          nil
        end


        def extract_text_content
          file.open do |tempfile|
            content = tempfile.read

            # Cache the extracted content in file metadata
            file.metadata['extracted_content'] = content if content.present?

            content
          end
        rescue StandardError => e
          puts "Text extraction failed: #{e.message}"
          nil
        end


        # Default model names for each content type
        def default_text_model
          'text-embedding-3-large'
        end

        def default_image_model
          'clip-vit-large-patch14'
        end

        def default_audio_model
          'whisper-embedding-v1'
        end

        # Extraction helper methods (stubs - implement based on your needs)
        def extract_image_description
          # TODO: Implement with vision AI or manual description
          nil
        end

        def extract_image_dimensions
          # TODO: Extract from image metadata
          {}
        end

        def extract_audio_transcript
          # TODO: Implement with Whisper or other speech-to-text
          nil
        end

        def extract_audio_duration
          # TODO: Extract from audio metadata
          nil
        end

        def extract_audio_sample_rate
          # TODO: Extract from audio metadata
          nil
        end

        # Get document statistics
        def self.stats
          {
            total_documents: count,
            by_status: group(:status).count,
            by_type: group(:document_type).count,
            multi_modal_documents: joins(:text_contents, :image_contents).distinct.count +
                                  joins(:text_contents, :audio_contents).distinct.count +
                                  joins(:image_contents, :audio_contents).distinct.count,
            total_text_contents: joins(:text_contents).count,
            total_image_contents: joins(:image_contents).count,
            total_audio_contents: joins(:audio_contents).count,
            total_embeddings: {
              text: joins(:text_embeddings).count,
              image: joins(:image_embeddings).count,
              audio: joins(:audio_embeddings).count
            },
            storage_type: 'activerecord_polymorphic'
          }
        end
      end
    end
  end
end
