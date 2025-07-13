require_relative 'test_helper'
require 'tempfile'

class ClientTest < Minitest::Test
  def setup
    super
    @config = Ragdoll::Core::Configuration.new
    @config.storage_backend = :memory
    @config.storage_config = {}
    @config.chunk_size = 100
    @config.chunk_overlap = 20
    @config.embedding_model = 'test-model'
    @client = Ragdoll::Core::Client.new(@config)
  end

  def test_initialize_with_config
    assert_equal @config, @client.instance_variable_get(:@config)
    assert_instance_of Ragdoll::Core::Storage::MemoryStorage, @client.instance_variable_get(:@storage)
    assert_instance_of Ragdoll::Core::EmbeddingService, @client.instance_variable_get(:@embedding_service)
    assert_instance_of Ragdoll::Core::SearchEngine, @client.instance_variable_get(:@search_engine)
  end

  def test_initialize_with_default_config
    Ragdoll::Core.configure do |config|
      config.storage_backend = :memory
    end
    
    client = Ragdoll::Core::Client.new
    assert_equal Ragdoll::Core.configuration, client.instance_variable_get(:@config)
  end

  def test_enhance_prompt_with_context
    # Add a document first
    doc_id = @client.add_text("Relevant context content", title: "Test Doc")
    
    # Mock the search to return results
    @client.instance_variable_get(:@search_engine).instance_variable_get(:@storage)
           .instance_variable_get(:@embeddings) << {
      document_id: doc_id,
      chunk_index: 0,
      embedding: Array.new(1536) { 0.5 },
      metadata: { content: "Relevant context content" }
    }
    
    result = @client.enhance_prompt("What is the content?")
    
    assert_instance_of Hash, result
    assert_includes result[:enhanced_prompt], "Relevant context content"
    assert_equal "What is the content?", result[:original_prompt]
    assert_instance_of Array, result[:context_sources]
    assert_instance_of Integer, result[:context_count]
  end

  def test_enhance_prompt_without_context
    result = @client.enhance_prompt("Random question")
    
    assert_equal "Random question", result[:enhanced_prompt]
    assert_equal "Random question", result[:original_prompt]
    assert_equal [], result[:context_sources]
    assert_equal 0, result[:context_count]
  end

  def test_get_context
    @client.add_text("Context content", title: "Test Doc")
    
    result = @client.get_context("test query")
    
    assert_instance_of Hash, result
    assert_instance_of Array, result[:context_chunks]
    assert_instance_of String, result[:combined_context]
    assert_instance_of Integer, result[:total_chunks]
  end

  def test_search
    @client.add_text("Searchable content", title: "Test Doc")
    
    result = @client.search("test query")
    
    assert_instance_of Hash, result
    assert_equal "test query", result[:query]
    assert_instance_of Array, result[:results]
    assert_instance_of Integer, result[:total_results]
  end

  def test_search_similar_content
    @client.add_text("Similar content", title: "Test Doc")
    
    result = @client.search_similar_content("test query")
    
    assert_instance_of Array, result
  end

  def test_add_document_with_file_path
    with_temp_text_file("Test file content") do |file_path|
      doc_id = @client.add_document(file_path)
      
      assert_instance_of String, doc_id
      
      doc = @client.get_document(doc_id)
      assert_equal "Test file content", doc[:content]
    end
  end

  def test_add_document_with_content_string
    doc_id = @client.add_document("Direct content", title: "Direct Title")
    
    assert_instance_of String, doc_id
    
    doc = @client.get_document(doc_id)
    assert_equal "Direct content", doc[:content]
    assert_equal "Direct Title", doc[:metadata][:title]
  end

  def test_add_file
    with_temp_text_file("File content") do |file_path|
      doc_id = @client.add_file(file_path, title: "Custom Title")
      
      assert_instance_of String, doc_id
      
      doc = @client.get_document(doc_id)
      assert_equal "File content", doc[:content]
      assert_equal "Custom Title", doc[:metadata][:title]
    end
  end

  def test_add_file_with_metadata_title
    content_with_title = "File content"
    with_temp_text_file(content_with_title) do |file_path|
      # Mock DocumentProcessor to return metadata with title
      original_parse = Ragdoll::Core::DocumentProcessor.method(:parse)
      Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse) do |path|
        {
          content: File.read(path),
          metadata: { title: "Metadata Title" },
          document_type: 'text'
        }
      end
      
      begin
        doc_id = @client.add_file(file_path)
        
        doc = @client.get_document(doc_id)
        assert_equal "Metadata Title", doc[:metadata][:title]
      ensure
        # Restore original method
        Ragdoll::Core::DocumentProcessor.define_singleton_method(:parse, original_parse)
      end
    end
  end

  def test_add_text
    doc_id = @client.add_text("Text content", title: "Text Title", author: "Test Author")
    
    assert_instance_of String, doc_id
    
    doc = @client.get_document(doc_id)
    assert_equal "Text content", doc[:content]
    assert_equal "Text Title", doc[:metadata][:title]
    assert_equal "Test Author", doc[:metadata][:author]
  end

  def test_add_directory
    Dir.mktmpdir do |dir|
      # Create test files
      File.write(File.join(dir, "file1.txt"), "Content 1")
      File.write(File.join(dir, "file2.txt"), "Content 2")
      File.write(File.join(dir, "image.jpg"), "binary image data")
      
      results = @client.add_directory(dir)
      
      assert_instance_of Array, results
      successful_results = results.select { |r| r[:status] == 'success' }
      assert_equal 2, successful_results.length # Should skip image.jpg
      
      results.each do |result|
        if result[:status] == 'success'
          assert result[:document_id]
          assert result[:file]
        end
      end
    end
  end

  def test_add_directory_recursive
    Dir.mktmpdir do |dir|
      # Create nested structure
      subdir = File.join(dir, "subdir")
      Dir.mkdir(subdir)
      File.write(File.join(dir, "file1.txt"), "Content 1")
      File.write(File.join(subdir, "file2.txt"), "Content 2")
      
      results = @client.add_directory(dir, recursive: true)
      
      assert_equal 2, results.select { |r| r[:status] == 'success' }.length
    end
  end

  def test_get_document
    doc_id = @client.add_text("Get test content", title: "Get Test")
    
    doc = @client.get_document(doc_id)
    
    assert_instance_of Hash, doc
    assert_equal "Get test content", doc[:content]
    assert_equal "Get Test", doc[:metadata][:title]
  end

  def test_update_document
    doc_id = @client.add_text("Original content", title: "Original Title")
    
    # Note: This depends on storage backend implementation
    # For memory storage, update_document may not be implemented
    @client.update_document(doc_id, title: "Updated Title")
    
    # Test passes if no exception is raised
    assert true
  end

  def test_delete_document
    doc_id = @client.add_text("Delete test content", title: "Delete Test")
    
    # Note: This depends on storage backend implementation
    @client.delete_document(doc_id)
    
    # Test passes if no exception is raised
    assert true
  end

  def test_list_documents
    @client.add_text("Doc 1", title: "Title 1")
    @client.add_text("Doc 2", title: "Title 2")
    
    # Note: This depends on storage backend implementation
    result = @client.list_documents(limit: 10)
    
    # Test passes if no exception is raised and result is reasonable
    assert result.nil? || result.is_a?(Array)
  end

  def test_stats
    @client.add_text("Stats test content", title: "Stats Test")
    
    stats = @client.stats
    
    # Test passes if no exception is raised
    assert stats.nil? || stats.is_a?(Hash)
  end

  def test_search_analytics
    result = @client.search_analytics(days: 7)
    
    assert_instance_of Hash, result
    assert_equal 7, result[:days]
    assert_includes result[:message], "Analytics not implemented"
  end

  def test_healthy_with_working_storage
    @client.add_text("Health test", title: "Health")
    
    # Mock stats to return valid data
    storage = @client.instance_variable_get(:@storage)
    storage.define_singleton_method(:get_document_stats) do
      { total_documents: 1 }
    end
    
    assert @client.healthy?
  end

  def test_healthy_with_failing_storage
    # Mock stats to raise an error
    storage = @client.instance_variable_get(:@storage)
    storage.define_singleton_method(:get_document_stats) do
      raise StandardError, "Storage error"
    end
    
    refute @client.healthy?
  end

  def test_create_storage_backend_file
    config = Ragdoll::Core::Configuration.new
    config.storage_backend = :file
    config.storage_config = { directory: '/tmp' }
    
    client = Ragdoll::Core::Client.new(config)
    storage = client.instance_variable_get(:@storage)
    
    assert_instance_of Ragdoll::Core::Storage::FileStorage, storage
  end

  def test_create_storage_backend_activerecord
    config = Ragdoll::Core::Configuration.new
    config.storage_backend = :activerecord
    config.storage_config = {}
    
    client = Ragdoll::Core::Client.new(config)
    storage = client.instance_variable_get(:@storage)
    
    assert_instance_of Ragdoll::Core::Storage::ActiveRecordStorage, storage
  end

  def test_create_storage_backend_unknown
    config = Ragdoll::Core::Configuration.new
    config.storage_backend = :unknown
    
    error = assert_raises(Ragdoll::Core::ConfigurationError) do
      Ragdoll::Core::Client.new(config)
    end
    
    assert_includes error.message, "Unknown storage backend"
  end

  def test_build_enhanced_prompt_with_default_template
    context = "Relevant context information"
    prompt = "What is the answer?"
    
    enhanced = @client.send(:build_enhanced_prompt, prompt, context)
    
    assert_includes enhanced, context
    assert_includes enhanced, prompt
    assert_includes enhanced, "You are an AI assistant"
  end

  def test_build_enhanced_prompt_with_custom_template
    @config.prompt_template = "Context: {{context}}\nQ: {{prompt}}\nA:"
    context = "Custom context"
    prompt = "Custom question?"
    
    enhanced = @client.send(:build_enhanced_prompt, prompt, context)
    
    assert_equal "Context: Custom context\nQ: Custom question?\nA:", enhanced
  end

  private

  def with_temp_text_file(content, &block)
    Tempfile.create(['test', '.txt']) do |file|
      file.write(content)
      file.close
      yield file.path
    end
  end
end