# frozen_string_literal: true

module DiscourseThreads
  class UpdateTopicManagers
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :manager_usernames

      validates :topic_id, presence: true
      validate :manager_limit

      def manager_usernames
        Array(super).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      end

      private

      def manager_limit
        return if manager_usernames.size <= DiscourseThreads::MAX_TOPIC_MANAGERS

        errors.add(:manager_usernames, :too_long)
      end
    end

    model :topic
    policy :can_manage_topic
    step :resolve_managers
    transaction { step :save_managers }

    private

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def can_manage_topic(guardian:, topic:)
      DiscourseThreads.can_manage_topic?(guardian, topic)
    end

    def resolve_managers(params:)
      usernames = params.manager_usernames
      users =
        if usernames.empty?
          []
        else
          DiscourseThreads
            .manager_user_scope
            .where(username_lower: usernames.map(&:downcase))
            .to_a
        end
      found = users.map { |user| user.username.downcase }.to_set
      missing =
        usernames.reject { |username| found.include?(username.downcase) }

      if missing.present?
        context[:missing_usernames] = missing
        fail!("missing_usernames")
      else
        username_positions = usernames.map(&:downcase).each_with_index.to_h
        context[:manager_users] = users.sort_by do |user|
          username_positions.fetch(user.username_lower, 0)
        end
      end
    end

    def save_managers(topic:, manager_users:)
      manager_ids =
        manager_users.map(&:id).reject { |user_id| user_id == topic.user_id }

      topic.custom_fields[
        DiscourseThreads::TOPIC_MANAGER_IDS_FIELD
      ] = manager_ids.to_json
      topic.save_custom_fields
    end
  end
end
