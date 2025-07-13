require_relative '../test_helper'

class Ragdoll::Core::Models::EmbeddingTest < Minitest::Test
  def setup
    super
    @document = Ragdoll::Core::Models::Document.create!(
      location: '/test.txt',
      content: 'Test content',
      title: 'Test Document',
      document_type: 'text',
      status: 'processed'
    )
  end


  def test_create_embedding
    embedding = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2, 0.3],
      content: 'Test chunk content',
      model_name: 'test-model'
    )

    assert embedding.persisted?
    assert_equal @document, embedding.document
    assert_equal 0, embedding.chunk_index
    assert_equal [0.1, 0.2, 0.3], embedding.embedding_vector
    assert_equal 'Test chunk content', embedding.content
    assert_equal 'test-model', embedding.model_name
  end


  def test_validations
    # Test required fields
    embedding = Ragdoll::Core::Models::Embedding.new
    refute embedding.valid?
    assert_includes embedding.errors.keys, :document_id
    assert_includes embedding.errors.keys, :chunk_index
    assert_includes embedding.errors.keys, :embedding_vector
    assert_includes embedding.errors.keys, :content
    assert_includes embedding.errors.keys, :model_name
  end


  def test_uniqueness_validation
    # Create first embedding
    Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk 1',
      model_name: 'test'
    )

    # Try to create duplicate
    duplicate = Ragdoll::Core::Models::Embedding.new(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.3, 0.4],
      content: 'chunk 2',
      model_name: 'test'
    )

    refute duplicate.valid?
    assert_includes duplicate.errors.keys, :chunk_index
  end


  def test_associations
    embedding = @document.embeddings.create!(
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk',
      model_name: 'test'
    )

    assert_equal @document, embedding.document
    assert_equal @document.id, embedding.document_id
  end


  def test_scopes
    embedding1 = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk 1',
      model_name: 'model-1'
    )

    Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 1,
      embedding_vector: [0.3, 0.4],
      content: 'chunk 2',
      model_name: 'model-2'
    )

    # Test by_model scope
    model1_embeddings = Ragdoll::Core::Models::Embedding.by_model('model-1')
    assert_equal 1, model1_embeddings.count
    assert_includes model1_embeddings, embedding1
  end


  def test_embedding_dimensions
    embedding = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2, 0.3, 0.4, 0.5],
      content: 'chunk',
      model_name: 'test'
    )

    assert_equal 5, embedding.embedding_dimensions
  end


  def test_mark_as_used
    embedding = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2],
      content: 'chunk',
      model_name: 'test'
    )

    assert_equal 0, embedding.usage_count
    assert_nil embedding.returned_at

    embedding.mark_as_used!
    embedding.reload

    assert_equal 1, embedding.usage_count
    assert_instance_of ActiveSupport::TimeWithZone, embedding.returned_at

    # Mark as used again
    embedding.mark_as_used!
    embedding.reload

    assert_equal 2, embedding.usage_count
  end


  def test_to_hash
    embedding = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2, 0.3],
      content: 'Test chunk',
      model_name: 'test-model',
      metadata: { source: 'test' },
      usage_count: 5
    )

    hash = embedding.to_hash

    assert_equal embedding.id.to_s, hash[:id]
    assert_equal @document.id.to_s, hash[:document_id]
    assert_equal @document.title, hash[:document_title]
    assert_equal @document.location, hash[:document_location]
    assert_equal 'Test chunk', hash[:content]
    assert_equal 0, hash[:chunk_index]
    assert_equal [0.1, 0.2, 0.3], hash[:embedding_vector]
    assert_equal 3, hash[:embedding_dimensions]
    assert_equal 'test-model', hash[:model_name]
    assert_equal({ source: 'test' }, hash[:metadata])
    assert_equal 5, hash[:usage_count]
    assert hash[:created_at]
  end


  def test_search_similar_basic
    # Create embeddings
    embedding1 = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [1.0, 0.0],
      content: 'similar content',
      model_name: 'test'
    )

    Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 1,
      embedding_vector: [0.0, 1.0],
      content: 'different content',
      model_name: 'test'
    )

    # Search with vector similar to embedding1
    results = Ragdoll::Core::Models::Embedding.search_similar([0.9, 0.1], threshold: 0.5)

    assert_equal 1, results.length
    assert_equal embedding1.id.to_s, results.first[:embedding_id]
    assert_equal 'similar content', results.first[:content]
    assert results.first[:similarity] > 0.5
  end


  def test_search_similar_with_filters
    doc2 = Ragdoll::Core::Models::Document.create!(
      location: '/doc2.txt',
      content: 'Doc 2 content',
      title: 'Doc 2',
      document_type: 'text',
      status: 'processed'
    )

    embedding1 = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [1.0, 0.0],
      content: 'content 1',
      model_name: 'model-1'
    )

    embedding2 = Ragdoll::Core::Models::Embedding.create!(
      document: doc2,
      chunk_index: 0,
      embedding_vector: [1.0, 0.0],
      content: 'content 2',
      model_name: 'model-2'
    )

    # Filter by document_id
    results = Ragdoll::Core::Models::Embedding.search_similar(
      [1.0, 0.0],
      filters: { document_id: @document.id }
    )
    assert_equal 1, results.length
    assert_equal embedding1.id.to_s, results.first[:embedding_id]

    # Filter by model_name
    results = Ragdoll::Core::Models::Embedding.search_similar(
      [1.0, 0.0],
      filters: { model_name: 'model-2' }
    )
    assert_equal 1, results.length
    assert_equal embedding2.id.to_s, results.first[:embedding_id]
  end


  def test_search_similar_with_usage_tracking
    embedding = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [1.0, 0.0],
      content: 'test content',
      model_name: 'test'
    )

    # Search should mark embedding as used
    Ragdoll::Core::Models::Embedding.search_similar([1.0, 0.0])

    embedding.reload
    assert_equal 1, embedding.usage_count
    assert_instance_of ActiveSupport::TimeWithZone, embedding.returned_at
  end


  def test_search_similar_threshold
    Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [1.0, 0.0],
      content: 'test content',
      model_name: 'test'
    )

    # High threshold should exclude results
    results = Ragdoll::Core::Models::Embedding.search_similar([0.5, 0.5], threshold: 0.9)
    assert_equal 0, results.length

    # Low threshold should include results
    results = Ragdoll::Core::Models::Embedding.search_similar([0.5, 0.5], threshold: 0.5)
    assert_equal 1, results.length
  end


  def test_search_similar_limit
    5.times do |i|
      Ragdoll::Core::Models::Embedding.create!(
        document: @document,
        chunk_index: i,
        embedding_vector: [0.8 + i * 0.05, 0.2 - i * 0.05],
        content: "content #{i}",
        model_name: 'test'
      )
    end

    results = Ragdoll::Core::Models::Embedding.search_similar([1.0, 0.0], limit: 3)
    assert_equal 3, results.length

    # Should be sorted by similarity (descending)
    similarities = results.map { |r| r[:similarity] }
    assert_equal similarities.sort.reverse, similarities
  end


  def test_serialization
    embedding = Ragdoll::Core::Models::Embedding.create!(
      document: @document,
      chunk_index: 0,
      embedding_vector: [0.1, 0.2, 0.3],
      content: 'test',
      model_name: 'test',
      metadata: { key: 'value', nested: { deep: 'data' } }
    )

    # Reload to test serialization
    embedding.reload

    assert_equal [0.1, 0.2, 0.3], embedding.embedding_vector
    assert_equal({ key: 'value', nested: { deep: 'data' } }, embedding.metadata)
  end
end
