# frozen_string_literal: true

module DiscourseThreads
  class UserTopicPreference < ::ActiveRecord::Base
    self.table_name = "discourse_threads_user_topic_preferences"

    belongs_to :user
    belongs_to :topic

    validates :user_id, presence: true
    validates :topic_id, presence: true
    validates :thread_mode_enabled, inclusion: { in: [true, false] }
  end
end
