# frozen_string_literal: true

# name: discourse-threads
# about: Thread support for Discourse - Allow users to activate/deactivate tree/thread view.
# version: 0.1
# author: Jonathan Dekhtiar <jonathan@dekhtiar.com>

register_asset "stylesheets/common/discourse-threads.scss"
register_svg_icon "up-down-left-right"
register_svg_icon "diagram-project"
register_svg_icon "user-gear"
register_svg_icon "arrow-up"
register_svg_icon "list"
enabled_site_setting :discourse_threads_enabled

module ::DiscourseThreads
  PLUGIN_NAME = "discourse-threads"
  TOPIC_MANAGER_IDS_FIELD = "discourse_threads_topic_manager_ids"
  MAX_TOPIC_MANAGERS = 10

  def self.manager_ids(topic)
    raw = topic.custom_fields[TOPIC_MANAGER_IDS_FIELD]
    values = raw.is_a?(String) ? JSON.parse(raw.presence || "[]") : Array(raw)
    values.map(&:to_i).reject(&:zero?).uniq.first(MAX_TOPIC_MANAGERS)
  rescue JSON::ParserError
    []
  end

  def self.manager_users(topic)
    ids = manager_ids(topic)
    return [] if ids.blank?

    users_by_id = User.where(id: ids).index_by(&:id)
    ids.filter_map { |id| users_by_id[id] }
  end

  def self.topic_manager_users(topic)
    users = []
    users << topic.user if topic&.user
    users.concat(
      manager_users(topic).reject { |user| user.id == topic.user_id }
    )
    users
  end

  def self.manager_user_scope
    allowed_bot_user_ids = []
    if defined?(::DiscourseNarrativeBot::BOT_USER_ID)
      allowed_bot_user_ids << ::DiscourseNarrativeBot::BOT_USER_ID
    end

    User.real(allowed_bot_user_ids: allowed_bot_user_ids)
  end

  def self.feature_available_for_topic?(topic)
    SiteSetting.discourse_threads_enabled &&
      SiteSetting.nested_replies_enabled && topic.present? &&
      !topic.private_message?
  end

  def self.normalized_manager_usernames(usernames)
    Array(usernames).map(&:to_s).map(&:strip).reject(&:blank?).uniq
  end

  def self.can_manage_topic?(guardian, topic)
    return false if guardian.blank? || guardian.user.blank? || topic.blank?
    return true if guardian.is_staff?
    return true if topic.user_id == guardian.user.id

    manager_ids(topic).include?(guardian.user.id)
  end

  def self.thread_root_post(topic, post)
    return if topic.blank? || post.blank? || post.is_first_post?
    if post.reply_to_post_number.blank? || post.reply_to_post_number == 1
      return post
    end

    root =
      NestedReplies.walk_ancestors(
        topic_id: topic.id,
        start_post_number: post.post_number,
        exclude_deleted: false,
        stop_at_op: true
      ).max_by(&:depth)

    Post.with_deleted.find_by(id: root.id) if root
  end

  def self.can_relocate_post?(guardian, topic, post, target_post = nil)
    return true if can_manage_topic?(guardian, topic)
    return false if guardian.blank? || guardian.user.blank?

    user_id = guardian.user.id
    thread_root_post(topic, post)&.user_id == user_id ||
      thread_root_post(topic, target_post)&.user_id == user_id
  end

  def self.thread_mode_enabled?(user, topic)
    default_enabled = SiteSetting.discourse_threads_default_thread_mode_enabled
    return default_enabled if user.blank? || topic.blank?

    preference = UserTopicPreference.find_by(user: user, topic: topic)
    preference.present? ? preference.thread_mode_enabled : default_enabled
  end
end

require_relative "lib/discourse_threads/engine"

Discourse::Application.routes.append do
  mount DiscourseThreads::Engine, at: "/threads"
  mount DiscourseThreads::Engine, at: "/thread", as: "legacy_discourse_threads"
end

after_initialize do
  require_relative "app/models/discourse_threads/user_topic_preference"
  require_relative "app/services/discourse_threads/move_post_to_thread"
  require_relative "app/services/discourse_threads/update_topic_managers"
  require_relative "app/services/discourse_threads/update_topic_preference"

  register_topic_custom_field_type(
    DiscourseThreads::TOPIC_MANAGER_IDS_FIELD,
    :json
  )
  add_permitted_post_create_param(
    :discourse_threads_topic_manager_usernames,
    :array
  )

  on(:after_validate_topic) do |topic, topic_creator|
    next if !SiteSetting.discourse_threads_enabled || topic.private_message?

    usernames =
      DiscourseThreads.normalized_manager_usernames(
        topic_creator.opts[:discourse_threads_topic_manager_usernames]
      )

    if usernames.size > DiscourseThreads::MAX_TOPIC_MANAGERS
      topic.errors.add(
        :base,
        I18n.t(
          "discourse_threads.errors.too_many_topic_managers",
          count: DiscourseThreads::MAX_TOPIC_MANAGERS
        )
      )
    end
  end

  on(:topic_created) do |topic, opts, _user|
    next if topic.private_message?

    usernames =
      DiscourseThreads.normalized_manager_usernames(
        opts[:discourse_threads_topic_manager_usernames]
      )

    if usernames.present?
      users =
        DiscourseThreads
          .manager_user_scope
          .where(username_lower: usernames.map(&:downcase))
          .to_a
      manager_ids =
        users.map(&:id).reject { |user_id| user_id == topic.user_id }
      topic.custom_fields[
        DiscourseThreads::TOPIC_MANAGER_IDS_FIELD
      ] = manager_ids.to_json
      topic.save_custom_fields
    end
  end

  module ::DiscourseThreads::TopicViewSerializerExtension
    def is_nested_view
      return true if discourse_threads_active_for_user?

      super
    end

    def include_is_nested_view?
      super || discourse_threads_active_for_user?
    end

    private

    def discourse_threads_active_for_user?
      DiscourseThreads.feature_available_for_topic?(object.topic) &&
        DiscourseThreads.thread_mode_enabled?(scope.user, object.topic)
    end
  end

  reloadable_patch do
    TopicViewSerializer.prepend DiscourseThreads::TopicViewSerializerExtension
  end

  add_to_serializer(:topic_view, :discourse_threads_available) do
    DiscourseThreads.feature_available_for_topic?(object.topic)
  end

  add_to_serializer(:topic_view, :discourse_threads_thread_mode_enabled) do
    DiscourseThreads.feature_available_for_topic?(object.topic) &&
      DiscourseThreads.thread_mode_enabled?(scope.user, object.topic)
  end

  add_to_serializer(:topic_view, :discourse_threads_can_manage) do
    DiscourseThreads.feature_available_for_topic?(object.topic) &&
      DiscourseThreads.can_manage_topic?(scope, object.topic)
  end

  add_to_serializer(:post, :discourse_threads_can_move) do
    DiscourseThreads.feature_available_for_topic?(object.topic) &&
      !object.is_first_post? && object.deleted_at.blank? &&
      DiscourseThreads.can_relocate_post?(scope, object.topic, object)
  end

  add_to_serializer(:topic_view, :discourse_threads_topic_managers) do
    next [] if !DiscourseThreads.feature_available_for_topic?(object.topic)

    DiscourseThreads
      .topic_manager_users(object.topic)
      .map do |user|
        {
          id: user.id,
          username: user.username,
          name: user.name,
          avatar_template: user.avatar_template,
          locked: user.id == object.topic.user_id,
          owner: user.id == object.topic.user_id
        }
      end
  end
end
