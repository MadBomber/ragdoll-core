# frozen_string_literal: true

require 'delegate'
require_relative 'ragdoll/core'

module Ragdoll
  extend SingleForwardable

  # Delegate high-level API methods to Ragdoll::Core
  def_delegators 'Ragdoll::Core', :add_document, :search, :enhance_prompt, 
                 :get_document, :list_documents, :delete_document, 
                 :update_document, :get_context, :search_similar_content,
                 :add_directory, :stats, :healthy?, :configure, :configuration,
                 :reset_configuration!, :client
end