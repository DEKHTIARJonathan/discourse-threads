# frozen_string_literal: true

module DiscourseThreads
  class UpdateTopicPreference
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :thread_mode_enabled, :boolean

      validates :topic_id, presence: true
      validates :thread_mode_enabled, inclusion: { in: [true, false] }
    end

    model :topic
    policy :can_see_topic
    transaction { step :persist_preference }

    private

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_see_topic(guardian:, topic:)
      guardian.can_see?(topic)
    end

    def persist_preference(params:, guardian:, topic:)
      default_enabled =
        SiteSetting.discourse_threads_default_thread_mode_enabled

      if params.thread_mode_enabled == default_enabled
        UserTopicPreference.where(user: guardian.user, topic: topic).delete_all
      else
        preference =
          UserTopicPreference.find_or_initialize_by(
            user: guardian.user,
            topic: topic
          )
        preference.thread_mode_enabled = params.thread_mode_enabled
        preference.save!
      end
    end
  end
end
