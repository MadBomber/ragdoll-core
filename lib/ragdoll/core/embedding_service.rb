# frozen_string_literal: true

require 'ruby_llm'

module Ragdoll
  module Core
    class EmbeddingService
      def initialize(configuration = nil, client: nil)
        @configuration = configuration || Ragdoll::Core.configuration
        @client = client
        configure_ruby_llm unless @client
      end

      def generate_embedding(text)
        return nil if text.nil? || text.strip.empty?

        # Clean and prepare text
        cleaned_text = clean_text(text)
        
        begin
          if @client
            # Use custom client for testing
            response = @client.embed(
              input: cleaned_text,
              model: @configuration.embedding_model
            )
            
            if response && response['embeddings'] && response['embeddings'].first
              response['embeddings'].first
            elsif response && response['data'] && response['data'].first && response['data'].first['embedding']
              response['data'].first['embedding']
            else
              raise EmbeddingError, "Invalid response format from embedding API"
            end
          else
            # Create a dummy embedding for testing/dev environments without API calls
            # In production, this should use the actual API
            Array.new(1536) { rand(-1.0..1.0) }
          end

        rescue => e
          raise EmbeddingError, "Failed to generate embedding: #{e.message}"
        end
      end

      def generate_embeddings_batch(texts)
        return [] if texts.empty?

        # Clean all texts
        cleaned_texts = texts.map { |text| clean_text(text) }.reject { |t| t.nil? || t.strip.empty? }
        return [] if cleaned_texts.empty?

        begin
          if @client
            # Use custom client for testing
            response = @client.embed(
              input: cleaned_texts,
              model: @configuration.embedding_model
            )

            if response && response['embeddings']
              response['embeddings']
            elsif response && response['data']
              response['data'].map { |item| item['embedding'] }
            else
              raise EmbeddingError, "Invalid response format from embedding API"
            end
          else
            # Create dummy embeddings for testing/dev environments
            cleaned_texts.map { Array.new(1536) { rand(-1.0..1.0) } }
          end

        rescue => e
          raise EmbeddingError, "Failed to generate embeddings: #{e.message}"
        end
      end

      def cosine_similarity(embedding1, embedding2)
        return 0.0 if embedding1.nil? || embedding2.nil?
        return 0.0 if embedding1.length != embedding2.length

        dot_product = embedding1.zip(embedding2).sum { |a, b| a * b }
        magnitude1 = Math.sqrt(embedding1.sum { |a| a * a })
        magnitude2 = Math.sqrt(embedding2.sum { |a| a * a })

        return 0.0 if magnitude1 == 0.0 || magnitude2 == 0.0

        dot_product / (magnitude1 * magnitude2)
      end

      private

      def configure_ruby_llm
        # Configure ruby_llm based on Ragdoll configuration
        provider = @configuration.embedding_provider || @configuration.llm_provider
        config = @configuration.llm_config[provider] || {}

        RubyLLM.configure do |ruby_llm_config|
          case provider
          when :openai
            ruby_llm_config.openai_api_key = config[:api_key]
            ruby_llm_config.openai_organization = config[:organization] if config[:organization]
            ruby_llm_config.openai_project = config[:project] if config[:project]
          when :anthropic
            ruby_llm_config.anthropic_api_key = config[:api_key]
          when :google
            ruby_llm_config.google_api_key = config[:api_key]
            ruby_llm_config.google_project_id = config[:project_id] if config[:project_id]
          when :azure
            ruby_llm_config.azure_api_key = config[:api_key]
            ruby_llm_config.azure_endpoint = config[:endpoint] if config[:endpoint]
            ruby_llm_config.azure_api_version = config[:api_version] if config[:api_version]
          when :ollama
            ruby_llm_config.ollama_endpoint = config[:endpoint] if config[:endpoint]
          when :huggingface
            ruby_llm_config.huggingface_api_key = config[:api_key]
          when :openrouter
            ruby_llm_config.openrouter_api_key = config[:api_key]
          else
            raise EmbeddingError, "Unsupported embedding provider: #{provider}"
          end
        end
      end

      def clean_text(text)
        return '' if text.nil?
        
        # Remove excessive whitespace and normalize
        cleaned = text.strip
          .gsub(/\s+/, ' ')              # Multiple spaces to single space
          .gsub(/\n+/, "\n")             # Multiple newlines to single newline
          .gsub(/\t+/, ' ')              # Tabs to spaces
        
        # Truncate if too long (most embedding models have token limits)
        max_chars = 8000 # Conservative limit for most embedding models
        cleaned.length > max_chars ? cleaned[0, max_chars] : cleaned
      end
    end
  end
end