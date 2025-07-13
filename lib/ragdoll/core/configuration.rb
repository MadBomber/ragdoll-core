# frozen_string_literal: true

module Ragdoll
  module Core
    class Configuration
      attr_accessor :llm_provider, :llm_config, :embedding_model, :embedding_provider,
                    :chunk_size, :chunk_overlap, :search_similarity_threshold, :max_search_results,
                    :default_model, :prompt_template, :enable_search_analytics, :cache_embeddings,
                    :max_embedding_dimensions, :enable_document_summarization, :summary_model,
                    :summary_max_length, :summary_min_content_length, :enable_usage_tracking,
                    :usage_ranking_enabled, :usage_recency_weight, :usage_frequency_weight,
                    :usage_similarity_weight, :database_config,
                    :summary_provider_model, :keywords_provider_model, :embeddings_provider_model

      def initialize
        @llm_provider = :openai
        @llm_config = default_llm_config
        @embedding_provider = :openai
        @embedding_model = 'text-embedding-3-small'
        @chunk_size = 1000
        @chunk_overlap = 200
        @search_similarity_threshold = 0.7
        @max_search_results = 10
        @default_model = 'gpt-4'
        @prompt_template = nil # Use default template if nil
        @enable_search_analytics = true
        @cache_embeddings = true
        @max_embedding_dimensions = 3072 # Support up to text-embedding-3-large
        @enable_document_summarization = true
        @summary_model = nil # Use default_model if nil
        @summary_max_length = 300
        @summary_min_content_length = 300
        @enable_usage_tracking = true
        @usage_ranking_enabled = true
        @usage_recency_weight = 0.3
        @usage_frequency_weight = 0.7
        @usage_similarity_weight = 1.0
        @database_config = default_database_config
        @summary_provider_model = 'openai/gpt-4'
        @keywords_provider_model = 'openai/gpt-4'
        @embeddings_provider_model = 'openai/text-embedding-3-small'
      end


      def openai_api_key
        llm_config[:openai]&.dig(:api_key) || ENV['OPENAI_API_KEY']
      end


      def openai_api_key=(key)
        @llm_config[:openai] ||= {}
        @llm_config[:openai][:api_key] = key
      end


      def anthropic_api_key
        llm_config[:anthropic]&.dig(:api_key) || ENV['ANTHROPIC_API_KEY']
      end


      def anthropic_api_key=(key)
        @llm_config[:anthropic] ||= {}
        @llm_config[:anthropic][:api_key] = key
      end


      def google_api_key
        llm_config[:google]&.dig(:api_key) || ENV['GOOGLE_API_KEY']
      end


      def google_api_key=(key)
        @llm_config[:google] ||= {}
        @llm_config[:google][:api_key] = key
      end


      def azure_api_key
        llm_config[:azure]&.dig(:api_key) || ENV['AZURE_OPENAI_API_KEY']
      end


      def azure_api_key=(key)
        @llm_config[:azure] ||= {}
        @llm_config[:azure][:api_key] = key
      end


      def ollama_url
        llm_config[:ollama]&.dig(:endpoint) || ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434'
      end


      def ollama_url=(url)
        @llm_config[:ollama] ||= {}
        @llm_config[:ollama][:endpoint] = url
      end


      def huggingface_api_key
        llm_config[:huggingface]&.dig(:api_key) || ENV['HUGGINGFACE_API_KEY']
      end


      def huggingface_api_key=(key)
        @llm_config[:huggingface] ||= {}
        @llm_config[:huggingface][:api_key] = key
      end


      def openrouter_api_key
        llm_config[:openrouter]&.dig(:api_key) || ENV['OPENROUTER_API_KEY']
      end


      def openrouter_api_key=(key)
        @llm_config[:openrouter] ||= {}
        @llm_config[:openrouter][:api_key] = key
      end

      # Parse provider/model strings and return provider and model separately
      def summary_provider
        parse_provider_model(summary_provider_model)[:provider]
      end

      def summary_model_name
        parse_provider_model(summary_provider_model)[:model]
      end

      def keywords_provider
        parse_provider_model(keywords_provider_model)[:provider]
      end

      def keywords_model_name
        parse_provider_model(keywords_provider_model)[:model]
      end

      def embeddings_provider
        parse_provider_model(embeddings_provider_model)[:provider]
      end

      def embeddings_model_name
        parse_provider_model(embeddings_provider_model)[:model]
      end

      private

      # Parse a provider/model string into its components
      # Format: "provider/model" -> { provider: :provider, model: "model" }
      # Format: "model" -> { provider: nil, model: "model" } (RubyLLM determines provider)
      def parse_provider_model(provider_model_string)
        return { provider: nil, model: nil } if provider_model_string.nil? || provider_model_string.empty?

        parts = provider_model_string.split('/', 2)
        if parts.length == 2
          { provider: parts[0].to_sym, model: parts[1] }
        else
          # If no slash, let RubyLLM determine provider from model name
          { provider: nil, model: provider_model_string }
        end
      end

      def default_llm_config
        {
          openai: {
            api_key: ENV['OPENAI_API_KEY'],
            organization: ENV['OPENAI_ORGANIZATION'],
            project: ENV['OPENAI_PROJECT']
          },
          anthropic: {
            api_key: ENV['ANTHROPIC_API_KEY']
          },
          google: {
            api_key: ENV['GOOGLE_API_KEY'],
            project_id: ENV['GOOGLE_PROJECT_ID']
          },
          azure: {
            api_key: ENV['AZURE_OPENAI_API_KEY'],
            endpoint: ENV['AZURE_OPENAI_ENDPOINT'],
            api_version: ENV['AZURE_OPENAI_API_VERSION'] || '2024-02-01'
          },
          ollama: {
            endpoint: ENV['OLLAMA_ENDPOINT'] || 'http://localhost:11434'
          },
          huggingface: {
            api_key: ENV['HUGGINGFACE_API_KEY']
          },
          openrouter: {
            api_key: ENV['OPENROUTER_API_KEY']
          }
        }
      end


      def default_database_config
        {
          adapter: 'sqlite3',
          database: File.join(Dir.home, '.ragdoll', 'ragdoll.sqlite3'),
          timeout: 5000,
          auto_migrate: true,
          logger: nil # Set to Logger.new(STDOUT) for debugging
        }
      end
    end
  end
end
