require_relative 'test_helper'

class SearchEngineTest < Minitest::Test
  def setup
    super
    @embedding_service = Minitest::Mock.new
    @search_engine = Ragdoll::Core::SearchEngine.new(@embedding_service)
  end

  def teardown
    super
    @embedding_service.verify if @embedding_service
  end

  def test_initialize
    assert_equal @embedding_service, @search_engine.instance_variable_get(:@embedding_service)
  end

  def test_search_documents_with_default_options
    query = "test query"
    query_embedding = [0.1, 0.2, 0.3]

    @embedding_service.expect(:generate_embedding, query_embedding, [query])

    # Create a document and embedding for search
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    Ragdoll::Core::Models::Embedding.create!(
      document: document,
      chunk_index: 0,
      embedding_vector: query_embedding,
      content: 'Test content',
      model_name: 'test-model'
    )

    result = @search_engine.search_documents(query)
    
    assert_instance_of Array, result
    assert result.length > 0
    assert result.first[:content]
    assert result.first[:similarity]
  end

  def test_search_documents_with_nil_embedding
    query = "test query"

    @embedding_service.expect(:generate_embedding, nil, [query])

    result = @search_engine.search_documents(query)
    assert_equal [], result
  end

  def test_search_similar_content_with_string_query
    query = "test query"
    query_embedding = [0.1, 0.2, 0.3]

    @embedding_service.expect(:generate_embedding, query_embedding, [query])

    result = @search_engine.search_similar_content(query)
    assert_instance_of Array, result
  end

  def test_search_similar_content_with_embedding_array
    query_embedding = [0.1, 0.2, 0.3]

    result = @search_engine.search_similar_content(query_embedding)
    assert_instance_of Array, result
  end

  def test_add_document
    location = "/path/to/doc.txt"
    content = "Document content"
    metadata = { title: "Test Document" }
    
    doc_id = @search_engine.add_document(location, content, metadata)
    
    assert_instance_of String, doc_id
    
    # Verify document was created
    document = Ragdoll::Core::Models::Document.find(doc_id)
    assert_equal location, document.location
    assert_equal content, document.content
    assert_equal "Test Document", document.title
  end

  def test_add_document_with_title_extraction
    location = "/path/to/my_document.pdf"
    content = "Document content"
    
    doc_id = @search_engine.add_document(location, content)
    
    document = Ragdoll::Core::Models::Document.find(doc_id)
    assert_equal "my_document", document.title
  end

  def test_get_document
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    result = @search_engine.get_document(document.id)
    
    refute_nil result
    assert_equal document.id.to_s, result[:id]
    assert_equal '/test.txt', result[:location]
    assert_equal 'Test content', result[:content]
  end

  def test_get_document_with_invalid_id
    result = @search_engine.get_document(999999)
    
    assert_nil result
  end

  def test_update_document
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Original Title',
      document_type: 'text',
      status: 'processed'
    )
    
    result = @search_engine.update_document(document.id, title: 'Updated Title')
    
    refute_nil result
    assert_equal 'Updated Title', result[:title]
    
    # Verify in database
    document.reload
    assert_equal 'Updated Title', document.title
  end

  def test_update_document_with_invalid_id
    result = @search_engine.update_document(999999, title: 'New Title')
    
    assert_nil result
  end

  def test_delete_document
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    result = @search_engine.delete_document(document.id)
    
    assert_equal true, result
    
    # Verify document is deleted
    assert_nil Ragdoll::Core::Models::Document.find_by(id: document.id)
  end

  def test_delete_document_with_invalid_id
    result = @search_engine.delete_document(999999)
    
    assert_nil result
  end

  def test_list_documents
    doc1 = Ragdoll::Core::Models::Document.create!(
      location: '/doc1.txt',
      content: 'Content 1',
      title: 'Doc 1',
      document_type: 'text',
      status: 'processed'
    )
    
    doc2 = Ragdoll::Core::Models::Document.create!(
      location: '/doc2.txt',
      content: 'Content 2',
      title: 'Doc 2',
      document_type: 'text',
      status: 'processed'
    )
    
    result = @search_engine.list_documents
    
    assert_instance_of Array, result
    assert_equal 2, result.length
    assert result.any? { |doc| doc[:id] == doc1.id.to_s }
    assert result.any? { |doc| doc[:id] == doc2.id.to_s }
  end

  def test_list_documents_with_options
    5.times do |i|
      Ragdoll::Core::Models::Document.create!(
        location: "/doc#{i}.txt",
        content: "Content #{i}",
        title: "Doc #{i}",
        document_type: 'text',
        status: 'processed'
      )
    end
    
    result = @search_engine.list_documents(limit: 3, offset: 1)
    
    assert_equal 3, result.length
  end

  def test_get_document_stats
    doc = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    doc.embeddings.create!(
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk',
      model_name: 'test'
    )
    
    stats = @search_engine.get_document_stats
    
    assert_instance_of Hash, stats
    assert_equal 1, stats[:total_documents]
    assert_equal 1, stats[:total_embeddings]
    assert_equal 'activerecord', stats[:storage_type]
  end

  def test_add_embedding
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    embedding_id = @search_engine.add_embedding(
      document.id,
      0,
      [0.1, 0.2, 0.3],
      { content: 'chunk content', model_name: 'test-model' }
    )
    
    assert_instance_of String, embedding_id
    
    # Verify embedding was created
    embedding = Ragdoll::Core::Models::Embedding.find(embedding_id)
    assert_equal document.id, embedding.document_id
    assert_equal 0, embedding.chunk_index
    assert_equal [0.1, 0.2, 0.3], embedding.embedding_vector
    assert_equal 'chunk content', embedding.content
    assert_equal 'test-model', embedding.model_name
  end
end