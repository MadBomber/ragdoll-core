# frozen_string_literal: true

require_relative "core/version"
require_relative "core/errors"
require_relative "core/configuration"
require_relative "core/database"
require_relative "core/models/document"
require_relative "core/models/embedding"
require_relative "core/document_processor"
require_relative "core/text_chunker"
require_relative "core/embedding_service"
require_relative "core/text_generation_service"
require_relative "core/search_engine"
require_relative "core/client"

module Ragdoll
  module Core
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
    end

    # Factory method for creating clients
    def self.client(config = nil)
      Client.new(config)
    end
  end
end