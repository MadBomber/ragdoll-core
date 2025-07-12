# frozen_string_literal: true

require 'active_record'

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

module Ragdoll
  module Core
    module Models
      class Document < ActiveRecord::Base
        self.table_name = 'ragdoll_documents'
        
        has_many :embeddings, 
                 class_name: 'Ragdoll::Core::Models::Embedding',
                 foreign_key: 'document_id',
                 dependent: :destroy
        
        validates :location, presence: true
        validates :content, presence: true
        validates :title, presence: true
        validates :document_type, presence: true
        validates :status, inclusion: { in: %w[pending processing processed error] }
        
        scope :processed, -> { where(status: 'processed') }
        scope :by_type, ->(type) { where(document_type: type) }
        scope :recent, -> { order(created_at: :desc) }
        
        def processed?
          status == 'processed'
        end
        
        def word_count
          content.split.length
        end
        
        def character_count
          content.length
        end
        
        def embedding_count
          embeddings.count
        end
        
        def to_hash
          {
            id: id.to_s,
            location: location,
            content: content,
            title: title,
            document_type: document_type,
            metadata: metadata || {},
            status: status,
            created_at: created_at,
            updated_at: updated_at,
            word_count: word_count,
            character_count: character_count,
            embedding_count: embedding_count
          }
        end
        
        # Search documents by content
        def self.search_content(query)
          where("content ILIKE ?", "%#{query}%")
            .or(where("title ILIKE ?", "%#{query}%"))
            .or(where("location ILIKE ?", "%#{query}%"))
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