# frozen_string_literal: true

require 'delegate'
require_relative 'ragdoll/core'

module Ragdoll
  # Delegate high-level API methods to Ragdoll::Core
  def self.add_document(*args, **kwargs)
    Ragdoll::Core.add_document(*args, **kwargs)
  end

  def self.search(*args, **kwargs)
    Ragdoll::Core.search(*args, **kwargs)
  end

  def self.enhance_prompt(*args, **kwargs)
    Ragdoll::Core.enhance_prompt(*args, **kwargs)
  end

  def self.get_document(*args, **kwargs)
    Ragdoll::Core.get_document(*args, **kwargs)
  end

  def self.list_documents(*args, **kwargs)
    Ragdoll::Core.list_documents(*args, **kwargs)
  end

  def self.delete_document(*args, **kwargs)
    Ragdoll::Core.delete_document(*args, **kwargs)
  end

  def self.document_status(*args, **kwargs)
    Ragdoll::Core.document_status(*args, **kwargs)
  end

  def self.update_document(*args, **kwargs)
    Ragdoll::Core.update_document(*args, **kwargs)
  end

  def self.get_context(*args, **kwargs)
    Ragdoll::Core.get_context(*args, **kwargs)
  end

  def self.search_similar_content(*args, **kwargs)
    Ragdoll::Core.search_similar_content(*args, **kwargs)
  end

  def self.add_directory(*args, **kwargs)
    Ragdoll::Core.add_directory(*args, **kwargs)
  end

  def self.stats(*args, **kwargs)
    Ragdoll::Core.stats(*args, **kwargs)
  end

  def self.healthy?(*args, **kwargs)
    Ragdoll::Core.healthy?(*args, **kwargs)
  end

  def self.configure(*args, **kwargs, &block)
    Ragdoll::Core.configure(*args, **kwargs, &block)
  end

  def self.configuration(*args, **kwargs)
    Ragdoll::Core.configuration(*args, **kwargs)
  end

  def self.reset_configuration!(*args, **kwargs)
    Ragdoll::Core.reset_configuration!(*args, **kwargs)
  end

  def self.client(*args, **kwargs)
    Ragdoll::Core.client(*args, **kwargs)
  end
end