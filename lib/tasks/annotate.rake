# frozen_string_literal: true

require 'annotate'

namespace :annotate do
  task :models do
    Annotate::Annotate.do_annotations({
                                        'models' => 'true',
                                        'position_in_class' => 'before',
                                        'show_foreign_keys' => 'true',
                                        'show_indexes' => 'true',
                                        'model_dir' => 'lib/ragdoll/core/models',
                                        'exclude_tests' => 'true',
                                        'exclude_fixtures' => 'true',
                                        'exclude_factories' => 'true',
                                        'exclude_serializers' => 'true',
                                        'exclude_scaffolds' => 'true',
                                        'exclude_controllers' => 'true',
                                        'exclude_helpers' => 'true'
                                      })
  end
end

task :set_annotation_options do
  # You can override any of these by setting an environment variable of the
  # same name.
  Annotate.set_defaults(
    'active_admin' => 'false',
    'additional_file_patterns' => [],
    'routes' => 'false',
    'models' => 'true',
    'position_in_routes' => 'before',
    'position_in_class' => 'before',
    'position_in_test' => 'before',
    'position_in_fixture' => 'before',
    'position_in_factory' => 'before',
    'position_in_serializer' => 'before',
    'show_foreign_keys' => 'true',
    'show_complete_foreign_keys' => 'false',
    'show_indexes' => 'true',
    'simple_indexes' => 'false',
    'model_dir' => 'lib/ragdoll/core/models',
    'root_dir' => '',
    'include_version' => 'false',
    'require' => '',
    'exclude_tests' => 'false',
    'exclude_fixtures' => 'false',
    'exclude_factories' => 'false',
    'exclude_serializers' => 'false',
    'exclude_scaffolds' => 'false',
    'exclude_controllers' => 'true',
    'exclude_helpers' => 'true',
    'exclude_sti_subclasses' => 'false',
    'ignore_model_sub_dir' => 'false',
    'ignore_columns' => nil,
    'ignore_routes' => nil,
    'ignore_unknown_options' => 'false',
    'hide_limit_column_types' => 'integer,bigint,boolean',
    'hide_default_column_types' => 'json,jsonb,hstore',
    'skip_on_db_migrate' => 'false',
    'format_bare' => 'true',
    'format_rdoc' => 'false',
    'format_yard' => 'false',
    'format_markdown' => 'false',
    'sort' => 'false',
    'force' => 'false',
    'frozen' => 'false',
    'classified_sort' => 'true',
    'trace' => 'false',
    'wrapper_open' => nil,
    'wrapper_close' => nil,
    'with_comment' => 'true'
  )
end

# Load only essential model annotation tasks
desc 'Add schema information (as comments) to model files'
task :annotate_models do
  Annotate::Annotate.do_annotations({
                                      'models' => 'true',
                                      'position_in_class' => 'before',
                                      'show_foreign_keys' => 'true',
                                      'show_indexes' => 'true',
                                      'model_dir' => 'lib/ragdoll/core/models',
                                      'exclude_tests' => 'true',
                                      'exclude_fixtures' => 'true',
                                      'exclude_factories' => 'true',
                                      'exclude_serializers' => 'true',
                                      'exclude_scaffolds' => 'true',
                                      'exclude_controllers' => 'true',
                                      'exclude_helpers' => 'true'
                                    })
end

desc 'Remove schema information from model files'
task :remove_annotation do
  Annotate::Annotate.remove_annotations({
                                          'models' => 'true',
                                          'model_dir' => 'lib/ragdoll/core/models'
                                        })
end
