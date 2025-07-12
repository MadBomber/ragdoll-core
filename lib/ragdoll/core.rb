# frozen_string_literal: true

require_relative "core/version"
require_relative "core/errors"
require_relative "core/configuration"
require_relative "core/document_processor"
require_relative "core/text_chunker"
require_relative "core/embedding_service"
require_relative "core/search_engine"
require_relative "core/client"

# Storage implementations
require_relative "core/storage/base"
require_relative "core/storage/memory_storage"
require_relative "core/storage/file_storage"

# ActiveRecord storage (optional - only load if ActiveRecord is available)
begin
  require_relative "core/storage/active_record_storage"
rescue LoadError
  # ActiveRecord not available, skip
end

module Ragdoll
  module Core
    # Module-level configuration access
    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    # Factory method for creating clients
    def self.client(options = {})
      Client.new(options)
    end
  end
end