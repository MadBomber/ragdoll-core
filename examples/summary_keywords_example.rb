#!/usr/bin/env ruby

# Example demonstrating summary and keywords functionality
# This example shows how documents automatically generate summaries and keywords

require 'bundler/setup'
require_relative '../lib/ragdoll-core'

# Configure ragdoll-core
Ragdoll::Core.configure do |config|
  config.database_config = {
    adapter: 'sqlite3',
    database: File.join(Dir.home, '.ragdoll', 'ragdoll_summary_example.sqlite3'),
    auto_migrate: true
  }
end

# Initialize the database
Ragdoll::Core::Database.setup

puts '=== Summary and Keywords Example ==='

# Example content about machine learning
ml_content = <<~TEXT
  Machine learning is a method of data analysis that automates analytical model building.#{' '}
  It is a branch of artificial intelligence based on the idea that systems can learn from data,#{' '}
  identify patterns and make decisions with minimal human intervention. Machine learning algorithms#{' '}
  build a model based on training data in order to make predictions or decisions without being#{' '}
  explicitly programmed to do so. Applications range from email filtering and computer vision#{' '}
  to recommendation systems and autonomous vehicles. The field has gained tremendous momentum#{' '}
  with the advent of big data, improved algorithms, and increased computational power.
TEXT

# Create a document and let it automatically generate summary and keywords
puts "\n1. Creating document with automatic summary and keywords generation..."
document = Ragdoll::Core::Models::Document.create!(
  location: 'machine_learning_intro.txt',
  title: 'Introduction to Machine Learning',
  content: ml_content,
  document_type: 'text',
  status: 'processed'
)

puts "Document ID: #{document.id}"
puts "Content length: #{document.character_count} characters"
puts "Has summary: #{document.has_summary?}"
puts "Has keywords: #{document.has_keywords?}"

puts "\n2. Generated Summary:"
puts "#{document.summary}"

puts "\n3. Extracted Keywords:"
puts "#{document.keywords}"
puts "Keywords array: #{document.keywords_array.inspect}"

# Example 2: Create another document
ai_content = <<~TEXT
  Artificial intelligence (AI) refers to the simulation of human intelligence in machines#{' '}
  that are programmed to think like humans and mimic their actions. The term may also be#{' '}
  applied to any machine that exhibits traits associated with a human mind such as learning#{' '}
  and problem-solving. AI research has been highly successful in developing effective#{' '}
  techniques for solving a wide range of problems, from game playing to medical diagnosis.#{' '}
  Neural networks, deep learning, natural language processing, and computer vision are#{' '}
  key areas of AI research and development.
TEXT

document2 = Ragdoll::Core::Models::Document.create!(
  location: 'ai_overview.txt',
  title: 'Artificial Intelligence Overview',
  content: ai_content,
  document_type: 'text',
  status: 'processed'
)

puts "\n4. Second Document - AI Overview:"
puts "Summary: #{document2.summary}"
puts "Keywords: #{document2.keywords}"

# Demonstrate keyword management
puts "\n5. Keyword Management:"
puts "Before adding keyword: #{document.keywords_array}"
document.add_keyword('supervised learning')
document.add_keyword('neural networks')
document.save!
puts "After adding keywords: #{document.keywords_array}"

# Demonstrate faceted search
puts "\n6. Faceted Search Capabilities:"
all_keywords = Ragdoll::Core::Models::Document.all_keywords
puts "All available keywords: #{all_keywords.first(10).join(', ')}..."

keyword_frequencies = Ragdoll::Core::Models::Document.keyword_frequencies
puts 'Top keyword frequencies:'
keyword_frequencies.first(5).each do |keyword, count|
  puts "  #{keyword}: #{count}"
end

# Search by keywords
puts "\n7. Search by Keywords:"
search_results = Ragdoll::Core::Models::Document.faceted_search(
  query: nil,
  keywords: %w[learning intelligence]
)
puts "Documents with 'learning' and 'intelligence' keywords: #{search_results.count}"

# Full-text search on summary and keywords
puts "\n8. Full-text Search (on summary and keywords):"
search_results = Ragdoll::Core::Models::Document.search_content('machine learning')
puts "Search results for 'machine learning': #{search_results.respond_to?(:count) ? search_results.count : search_results.length}"

# Combined search
puts "\n9. Combined Faceted Search:"
combined_results = Ragdoll::Core::Models::Document.faceted_search(
  query: 'artificial',
  keywords: ['intelligence'],
  limit: 10
)
puts "Combined search results: #{combined_results.count}"
combined_results.each do |doc|
  puts "  - #{doc.title} (#{doc.keywords_array.length} keywords)"
end

# Document hash with new fields
puts "\n10. Document Hash with Summary and Keywords:"
hash = document.to_hash
puts "Hash keys: #{hash.keys}"
puts "Summary present: #{hash[:has_summary]}"
puts "Keywords present: #{hash[:has_keywords]}"
puts "Keywords array: #{hash[:keywords_array].first(3).join(', ')}..."

puts "\n=== Summary and Keywords Integration Complete ==="
puts 'Documents now automatically generate summaries and extract keywords.'
puts 'Search functionality focuses on summary and keywords rather than raw content.'
puts 'Faceted search enables filtering by specific keywords.'
