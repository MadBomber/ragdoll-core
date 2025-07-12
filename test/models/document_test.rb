require_relative '../test_helper'

class Models::DocumentTest < Minitest::Test
  def test_create_document
    document = Ragdoll::Core::Models::Document.create!(
      location: '/path/to/doc.txt',
      content: 'Test content',
      title: 'Test Document',
      document_type: 'text',
      status: 'processed'
    )
    
    assert document.persisted?
    assert_equal '/path/to/doc.txt', document.location
    assert_equal 'Test content', document.content
    assert_equal 'Test Document', document.title
    assert_equal 'text', document.document_type
    assert_equal 'processed', document.status
  end

  def test_validations
    # Test required fields
    document = Ragdoll::Core::Models::Document.new
    refute document.valid?
    assert_includes document.errors.keys, :location
    assert_includes document.errors.keys, :content
    assert_includes document.errors.keys, :title
    assert_includes document.errors.keys, :document_type
  end

  def test_status_validation
    document = Ragdoll::Core::Models::Document.new(
      location: '/test',
      content: 'content',
      title: 'title',
      document_type: 'text',
      status: 'invalid_status'
    )
    
    refute document.valid?
    assert_includes document.errors.keys, :status
  end

  def test_associations
    document = Ragdoll::Core::Models::Document.create!(
      location: '/path/to/doc.txt',
      content: 'Test content',
      title: 'Test Document',
      document_type: 'text',
      status: 'processed'
    )
    
    embedding = document.embeddings.create!(
      chunk_index: 0,
      embedding_vector: [0.1, 0.2, 0.3],
      content: 'chunk content',
      model_name: 'test-model'
    )
    
    assert_equal 1, document.embeddings.count
    assert_equal document, embedding.document
  end

  def test_scopes
    doc1 = Ragdoll::Core::Models::Document.create!(
      location: '/doc1.txt',
      content: 'Content 1',
      title: 'Doc 1',
      document_type: 'text',
      status: 'processed'
    )
    
    doc2 = Ragdoll::Core::Models::Document.create!(
      location: '/doc2.pdf',
      content: 'Content 2',
      title: 'Doc 2',
      document_type: 'pdf',
      status: 'pending'
    )
    
    # Test processed scope
    processed_docs = Ragdoll::Core::Models::Document.processed
    assert_equal 1, processed_docs.count
    assert_includes processed_docs, doc1
    
    # Test by_type scope
    pdf_docs = Ragdoll::Core::Models::Document.by_type('pdf')
    assert_equal 1, pdf_docs.count
    assert_includes pdf_docs, doc2
  end

  def test_processed_query_method
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    assert document.processed?
    
    document.update!(status: 'pending')
    refute document.processed?
  end

  def test_word_count
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'This is a test document with several words',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    assert_equal 9, document.word_count
  end

  def test_character_count
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Hello world',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    assert_equal 11, document.character_count
  end

  def test_embedding_count
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test',
      document_type: 'text',
      status: 'processed'
    )
    
    assert_equal 0, document.embedding_count
    
    document.embeddings.create!(
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk',
      model_name: 'test'
    )
    
    assert_equal 1, document.embedding_count
  end

  def test_to_hash
    document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test Document',
      document_type: 'text',
      status: 'processed',
      metadata: { author: 'Test Author' }
    )
    
    hash = document.to_hash
    
    assert_equal document.id.to_s, hash[:id]
    assert_equal '/test.txt', hash[:location]
    assert_equal 'Test content', hash[:content]
    assert_equal 'Test Document', hash[:title]
    assert_equal 'text', hash[:document_type]
    assert_equal({ author: 'Test Author' }, hash[:metadata])
    assert_equal 'processed', hash[:status]
    assert hash[:created_at]
    assert hash[:updated_at]
    assert_equal 2, hash[:word_count]
    assert_equal 12, hash[:character_count]
    assert_equal 0, hash[:embedding_count]
  end

  def test_search_content
    doc1 = Ragdoll::Core::Models::Document.create!(
      location: '/doc1.txt',
      content: 'This document contains machine learning concepts',
      title: 'Machine Learning Doc',
      document_type: 'text',
      status: 'processed'
    )
    
    doc2 = Ragdoll::Core::Models::Document.create!(
      location: '/doc2.txt',
      content: 'This is about cooking recipes',
      title: 'Cooking Guide',
      document_type: 'text',
      status: 'processed'
    )
    
    # Search by content
    results = Ragdoll::Core::Models::Document.search_content('machine learning')
    assert_equal 1, results.count
    assert_includes results, doc1
    
    # Search by title
    results = Ragdoll::Core::Models::Document.search_content('cooking')
    assert_equal 1, results.count
    assert_includes results, doc2
    
    # Search by location
    results = Ragdoll::Core::Models::Document.search_content('doc1')
    assert_equal 1, results.count
    assert_includes results, doc1
  end

  def test_stats
    doc1 = Ragdoll::Core::Models::Document.create!(
      location: '/doc1.txt',
      content: 'Content 1',
      title: 'Doc 1',
      document_type: 'text',
      status: 'processed'
    )
    
    doc2 = Ragdoll::Core::Models::Document.create!(
      location: '/doc2.pdf',
      content: 'Content 2',
      title: 'Doc 2',
      document_type: 'pdf',
      status: 'pending'
    )
    
    doc1.embeddings.create!(
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk',
      model_name: 'test'
    )
    
    stats = Ragdoll::Core::Models::Document.stats
    
    assert_equal 2, stats[:total_documents]
    assert_equal({ 'processed' => 1, 'pending' => 1 }, stats[:by_status])
    assert_equal({ 'text' => 1, 'pdf' => 1 }, stats[:by_type])
    assert_equal 1, stats[:total_embeddings]
    assert_equal 'activerecord', stats[:storage_type]
  end
end