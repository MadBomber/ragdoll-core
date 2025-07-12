# frozen_string_literal: true

class CreateRagdollDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :ragdoll_documents do |t|
      t.string :location, null: false
      t.text :content, null: false
      t.string :title, null: false
      t.string :document_type, null: false, default: 'text'
      t.json :metadata, default: {}
      t.string :status, null: false, default: 'pending'
      
      t.timestamps
      
      t.index :location
      t.index :title
      t.index :document_type
      t.index :status
      t.index :created_at
    end
  end
end