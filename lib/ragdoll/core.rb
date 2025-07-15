# frozen_string_literal: true

require 'delegate'

require_relative 'core/version'
require_relative 'core/errors'
require_relative 'core/configuration'
require_relative 'core/database'
require_relative 'core/models/document'
require_relative 'core/models/embedding'
require_relative 'core/document_processor'
require_relative 'core/text_chunker'
require_relative 'core/embedding_service'
require_relative 'core/text_generation_service'
require_relative 'core/search_engine'
require_relative 'core/client'

module Ragdoll
  module Core
    extend SingleForwardable
    
    # Module-level configuration access
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    # Reset configuration (useful for testing)
    def self.reset_configuration!
      @configuration = nil
      @default_client = nil
    end

    # Factory method for creating clients
    def self.client(config = nil)
      Client.new(config)
    end

    # Delegate high-level API methods to default client
    def_delegators :default_client, :add_document, :search, :enhance_prompt, 
                   :get_document, :list_documents, :delete_document, 
                   :update_document, :get_context, :search_similar_content,
                   :add_directory, :stats, :healthy?

    private

    def self.default_client
      @default_client ||= Client.new
    end
  end
end
