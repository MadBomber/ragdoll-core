# frozen_string_literal: true

require 'active_record'
require 'active_storage'
require 'searchkick'

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
        
        # Full-text search integration - focuses on summary and keywords, not raw content
        searchkick word_start: [:title, :summary, :keywords], 
                  searchable: [:title, :summary, :keywords],
                  text_start: [:title],
                  word_middle: [:summary],
                  callbacks: :async
        
        # ActiveStorage file attachment (optional - only if ActiveStorage is properly set up)
        # Each document has exactly one file attachment
        if defined?(ActiveStorage) && respond_to?(:has_one_attached)
          has_one_attached :file
        end
        
        has_many :embeddings, 
                 class_name: 'Ragdoll::Core::Models::Embedding',
                 foreign_key: 'document_id',
                 dependent: :destroy
        
        validates :location, presence: true
        validates :title, presence: true
        validates :document_type, presence: true
        validates :status, inclusion: { in: %w[pending processing processed error] }
        
        # Content is optional when file is attached
        validates :content, presence: true, unless: :file_attached?
        
        scope :processed, -> { where(status: 'processed') }
        scope :by_type, ->(type) { where(document_type: type) }
        scope :recent, -> { order(created_at: :desc) }
        scope :with_files, -> { joins(:file_attachment) }
        scope :without_files, -> { left_joins(:file_attachment).where(active_storage_attachments: { id: nil }) }
        
        # Callbacks to generate summary, extract keywords, and process files
        before_save :generate_summary_and_keywords, if: :content_changed?
        after_commit :extract_content_from_file, on: [:create, :update], if: :file_attached_and_content_empty?
        
        def processed?
          status == 'processed'
        end
        
        def word_count
          effective_content.split.length
        end
        
        def character_count
          effective_content.length
        end
        
        def embedding_count
          embeddings.count
        end
        
        # Summary and keywords related methods
        def has_summary?
          summary.present?
        end
        
        def has_keywords?
          keywords.present?
        end
        
        def keywords_array
          return [] unless keywords.present?
          keywords.split(',').map(&:strip).reject(&:empty?)
        end
        
        def add_keyword(keyword)
          current_keywords = keywords_array
          unless current_keywords.include?(keyword.strip)
            current_keywords << keyword.strip
            self.keywords = current_keywords.join(', ')
          end
        end
        
        def remove_keyword(keyword)
          current_keywords = keywords_array
          current_keywords.delete(keyword.strip)
          self.keywords = current_keywords.join(', ')
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
        
        def effective_content
          content.present? ? content : extracted_content || ''
        end
        
        def extracted_content
          return nil unless file_attached?
          
          # Try to get content from metadata first (cached)
          cached_content = file.metadata['extracted_content'] if file.metadata.present?
          return cached_content if cached_content.present?
          
          # Extract content based on file type
          extract_text_from_file
        end
        
        def to_hash
          hash = {
            id: id.to_s,
            location: location,
            content: effective_content,
            title: title,
            summary: summary,
            keywords: keywords,
            keywords_array: keywords_array,
            document_type: document_type,
            metadata: metadata || {},
            status: status,
            created_at: created_at,
            updated_at: updated_at,
            word_count: word_count,
            character_count: character_count,
            embedding_count: embedding_count,
            file_attached: file_attached?,
            has_summary: has_summary?,
            has_keywords: has_keywords?
          }
          
          if file_attached?
            hash.merge!({
              file_size: file_size,
              file_content_type: file_content_type,
              file_filename: file_filename
            })
          end
          
          hash
        end
        
        # Enhanced search using searchkick for full-text search on summary and keywords
        def self.search_content(query, **options)
          # Use searchkick if available, fallback to SQL LIKE
          if searchkick_enabled?
            search(query, **search_options(options))
          else
            sql_search(query)
          end
        end
        
        # Full-text search with searchkick on summary and keywords
        def self.full_text_search(query, **options)
          search(query, **search_options(options))
        end
        
        # Faceted search by keywords
        def self.faceted_search(query: nil, keywords: [], **options)
          scope = all
          
          # Filter by keywords if provided
          if keywords.any?
            keyword_conditions = keywords.map { |keyword| "keywords LIKE ?" }.join(' AND ')
            keyword_values = keywords.map { |keyword| "%#{keyword}%" }
            scope = scope.where(keyword_conditions, *keyword_values)
          end
          
          # Apply text search if query provided
          if query.present?
            if searchkick_enabled?
              # Use searchkick for text search within the filtered scope
              ids = scope.pluck(:id)
              search_results = search(query, **search_options(options.merge(where: { id: ids })))
              return search_results
            else
              scope = scope.where(
                "title ILIKE ? OR summary ILIKE ? OR keywords ILIKE ?",
                "%#{query}%", "%#{query}%", "%#{query}%"
              )
            end
          end
          
          scope.limit(options[:limit] || 20)
        end
        
        # Get all unique keywords for faceted search
        def self.all_keywords
          where.not(keywords: [nil, '']).pluck(:keywords)
               .flat_map { |k| k.split(',').map(&:strip) }
               .uniq
               .sort
        end
        
        # Get keyword frequencies for faceted search
        def self.keyword_frequencies
          frequencies = Hash.new(0)
          where.not(keywords: [nil, '']).pluck(:keywords).each do |keyword_string|
            keyword_string.split(',').map(&:strip).each do |keyword|
              frequencies[keyword] += 1
            end
          end
          frequencies.sort_by { |k, v| -v }.to_h
        end
        
        # Hybrid search combining semantic and full-text search
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
          
          # Get full-text search results
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
                           .map do |doc_id, doc_results|
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
            content: content,
            document_type: document_type,
            location: location,
            status: status,
            word_count: word_count,
            character_count: character_count
          }
          
          # Add metadata if present
          if metadata.present?
            data.merge!(metadata.transform_keys { |k| "metadata_#{k}" })
          end
          
          data
        end
        
        private
        
        def self.searchkick_enabled?
          defined?(Searchkick) && respond_to?(:search)
        end
        
        def self.search_options(options)
          {
            fields: options[:fields] || [:title, :summary, :keywords],
            match: options[:match] || :word_start,
            limit: options[:limit] || 20,
            offset: options[:offset] || 0,
            where: options[:where] || {},
            order: options[:order] || { _score: :desc }
          }
        end
        
        def self.sql_search(query)
          where("summary ILIKE ? OR keywords ILIKE ?", "%#{query}%", "%#{query}%")
            .or(where("title ILIKE ?", "%#{query}%"))
            .or(where("location ILIKE ?", "%#{query}%"))
        end
        
        def self.embeddings_search(query_embedding, **options)
          Ragdoll::Core::Models::Embedding.search_similar(query_embedding, **options)
        end
        
        # Generate summary and extract keywords from content using ruby_llm
        def generate_summary_and_keywords
          return unless content.present?
          
          text_service = Ragdoll::Core::TextGenerationService.new
          
          # Generate summary using ruby_llm
          self.summary = text_service.generate_summary(content)
          
          # Extract keywords using ruby_llm
          keywords_array = text_service.extract_keywords(content)
          self.keywords = keywords_array.join(', ')
        end
        
        
        # File processing methods
        def file_attached_and_content_empty?
          file_attached? && content.blank?
        end
        
        def extract_content_from_file
          return unless file_attached?
          return if content.present? # Don't overwrite existing content
          
          extracted = extract_text_from_file
          if extracted.present?
            # Set content and generate summary/keywords
            self.content = extracted
            generate_summary_and_keywords
            
            # Save all changes
            update_columns(
              content: content,
              summary: summary,
              keywords: keywords,
              status: 'processed'
            )
          end
        rescue => e
          puts "Failed to extract content from file: #{e.message}"
          update_column(:status, 'error') if status == 'processing'
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
          else
            nil
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
        rescue => e
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
        rescue => e
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
        rescue => e
          puts "Text extraction failed: #{e.message}"
          nil
        end
        
        # Get document statistics
        def self.stats
          {
            total_documents: count,
            by_status: group(:status).count,
            by_type: group(:document_type).count,
            total_embeddings: joins(:embeddings).count,
            average_word_count: average('LENGTH(content) - LENGTH(REPLACE(content, \' \', \'\')) + 1'),
            storage_type: 'activerecord'
          }
        end
      end
    end
  end
end