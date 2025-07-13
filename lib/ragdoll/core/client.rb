# frozen_string_literal: true

module Ragdoll
  module Core
    class Client
      def initialize(config = nil)
        @config = config || Ragdoll::Core.configuration

        # Setup database connection
        Database.setup(@config.database_config)

        @embedding_service = EmbeddingService.new(@config)
        @search_engine = SearchEngine.new(@embedding_service)
      end


      # Primary method for RAG applications
      # Returns context-enhanced content for AI prompts
      def enhance_prompt(prompt, context_limit: 5, **options)
        context_data = get_context(prompt, limit: context_limit, **options)

        if context_data[:context_chunks].any?
          enhanced_prompt = build_enhanced_prompt(prompt, context_data[:combined_context])
          {
            enhanced_prompt: enhanced_prompt,
            original_prompt: prompt,
            context_sources: context_data[:context_chunks].map { |chunk| chunk[:source] },
            context_count: context_data[:total_chunks]
          }
        else
          {
            enhanced_prompt: prompt,
            original_prompt: prompt,
            context_sources: [],
            context_count: 0
          }
        end
      end


      # Get relevant context without prompt enhancement
      def get_context(query, limit: 10, **options)
        results = search_similar_content(query, limit: limit, **options)

        context_chunks = results.map do |result|
          {
            content: result[:content],
            source: result[:document_location],
            similarity: result[:similarity],
            chunk_index: result[:chunk_index]
          }
        end

        combined_context = context_chunks.map { |chunk| chunk[:content] }.join("\n\n")

        {
          context_chunks: context_chunks,
          combined_context: combined_context,
          total_chunks: context_chunks.length
        }
      end


      # Semantic search
      def search(query, **options)
        results = search_similar_content(query, **options)

        {
          query: query,
          results: results,
          total_results: results.length
        }
      end


      # Search similar content (core functionality)
      def search_similar_content(query_or_embedding, **options)
        @search_engine.search_similar_content(query_or_embedding, **options)
      end


      # Document management
      def add_document(location_or_content, **options)
        if File.exist?(location_or_content.to_s)
          # It's a file path
          add_file(location_or_content, **options)
        else
          # It's content
          title = options[:title] || 'Untitled Document'
          add_text(location_or_content, title: title, **options)
        end
      end


      def add_file(file_path, **options)
        # Parse the document
        parsed = DocumentProcessor.parse(file_path)

        # Extract title from metadata or use filename
        title = parsed[:metadata][:title] ||
                options[:title] ||
                File.basename(file_path, File.extname(file_path))

        # Add document to database
        doc_id = @search_engine.add_document(file_path, parsed[:content], {
                                               title: title,
                                               document_type: parsed[:document_type],
                                               **parsed[:metadata],
                                               **options
                                             })

        # Process and add embeddings
        process_document_embeddings(doc_id, parsed[:content], options)

        doc_id
      end


      def add_text(content, title:, **options)
        # Add document to database
        doc_id = @search_engine.add_document(title, content, {
                                               title: title,
                                               document_type: 'text',
                                               **options
                                             })

        # Process and add embeddings
        process_document_embeddings(doc_id, content, options)

        doc_id
      end


      def add_directory(directory_path, recursive: false, **options)
        results = []
        pattern = recursive ? File.join(directory_path, '**', '*') : File.join(directory_path, '*')

        Dir.glob(pattern).each do |file_path|
          next unless File.file?(file_path)
          next if file_path.match?(/\.(jpg|jpeg|png|gif|bmp|svg|ico)$/i) # Skip images

          begin
            doc_id = add_file(file_path, **options)
            results << { file: file_path, document_id: doc_id, status: 'success' }
          rescue StandardError => e
            results << { file: file_path, error: e.message, status: 'error' }
          end
        end

        results
      end


      def get_document(id)
        @search_engine.get_document(id)
      end


      def update_document(id, **updates)
        @search_engine.update_document(id, **updates)
      end


      def delete_document(id)
        @search_engine.delete_document(id)
      end


      def list_documents(**options)
        @search_engine.list_documents(options)
      end


      # Analytics and stats
      def stats
        @search_engine.get_document_stats
      end


      def search_analytics(days: 30)
        # This could be implemented with additional database queries
        Models::Embedding.where('returned_at > ?', days.days.ago)
                         .group('DATE(returned_at)')
                         .count
      end


      # Health check
      def healthy?

        Database.connected? && stats[:total_documents] >= 0
      rescue StandardError
        false

      end

      private

      def process_document_embeddings(doc_id, content, options = {})
        # Chunk the content
        chunk_size = options[:chunk_size] || @config.chunk_size
        chunk_overlap = options[:chunk_overlap] || @config.chunk_overlap

        chunks = TextChunker.chunk(content,
                                   chunk_size: chunk_size,
                                   chunk_overlap: chunk_overlap)

        # Generate embeddings for each chunk
        chunks.each_with_index do |chunk, index|
          embedding = @embedding_service.generate_embedding(chunk)
          next unless embedding

          @search_engine.add_embedding(doc_id, index, embedding, {
                                         content: chunk,
                                         model_name: @config.embedding_model,
                                         chunk_size: chunk_size,
                                         chunk_overlap: chunk_overlap
                                       })
        end
      end


      def build_enhanced_prompt(original_prompt, context)
        template = @config.prompt_template || default_prompt_template

        template
          .gsub('{{context}}', context)
          .gsub('{{prompt}}', original_prompt)
      end


      def default_prompt_template
        <<~TEMPLATE
          You are an AI assistant. Use the following context to help answer the user's question. If the context doesn't contain relevant information, say so.

          Context:
          {{context}}

          Question: {{prompt}}

          Answer:
        TEMPLATE
      end
    end
  end
end
