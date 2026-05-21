# frozen_string_literal: true

module DiscourseThreads
  class Engine < ::Rails::Engine
    engine_name DiscourseThreads::PLUGIN_NAME
    isolate_namespace DiscourseThreads
  end
end
