# frozen_string_literal: true

class CreateRagdollEmbeddings < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_embeddings do |t|
      t.references :document, null: false, foreign_key: { to_table: :ragdoll_documents }
      t.integer :chunk_index, null: false
      t.json :embedding_vector, null: false
      t.text :content, null: false
      t.string :model_name, null: false
      t.json :metadata, default: {}
      t.integer :usage_count, default: 0
      t.datetime :returned_at
      
      t.timestamps
      
      t.index [:document_id, :chunk_index], unique: true
      t.index :model_name
      t.index :usage_count
      t.index :returned_at
      t.index :created_at
    end
  end
end