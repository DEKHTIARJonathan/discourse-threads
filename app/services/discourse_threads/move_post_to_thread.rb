# frozen_string_literal: true

module DiscourseThreads
  class MovePostToThread
    include Service::Base

    params do
      attribute :topic_id, :integer
      attribute :post_id, :integer
      attribute :target_post_number, :integer

      validates :topic_id, presence: true
      validates :post_id, presence: true
      validates :target_post_number, presence: true
    end

    model :topic
    policy :feature_available
    model :post
    model :target_post
    policy :can_relocate_post
    policy :post_can_be_moved
    policy :valid_target
    policy :target_is_not_descendant
    transaction { step :move_post }

    private

    def fetch_topic(params:)
      Topic.find_by(id: params.topic_id)
    end

    def feature_available(topic:)
      DiscourseThreads.feature_available_for_topic?(topic)
    end

    def fetch_post(params:, topic:, guardian:)
      post = topic.posts.with_deleted.find_by(id: params.post_id)
      post if post && guardian.can_see_post?(post)
    end

    def fetch_target_post(params:, topic:, guardian:)
      post =
        topic.posts.with_deleted.find_by(post_number: params.target_post_number)
      post if post && guardian.can_see_post?(post)
    end

    def can_relocate_post(guardian:, topic:, post:, target_post:)
      DiscourseThreads.can_relocate_post?(guardian, topic, post, target_post)
    end

    def post_can_be_moved(post:)
      !post.is_first_post? && post.deleted_at.blank?
    end

    def valid_target(post:, target_post:)
      target_post.post_number != post.post_number
    end

    def target_is_not_descendant(topic:, post:, target_post:)
      return true if target_post.is_first_post?

      NestedReplies
        .walk_ancestors(
          topic_id: topic.id,
          start_post_number: target_post.post_number,
          exclude_deleted: false
        )
        .none? { |ancestor| ancestor.post_number == post.post_number }
    end

    def move_post(params:, post:, target_post:)
      previous_reply_to_post_number = post.reply_to_post_number
      old_reply_to_parent =
        if previous_reply_to_post_number.present?
          Post.with_deleted.find_by(
            topic_id: post.topic_id,
            post_number: previous_reply_to_post_number
          )
        end
      reply_to_post_number =
        target_post.is_first_post? ? nil : target_post.post_number

      post.reply_to_post_number = reply_to_post_number
      post.reply_to_user_id =
        target_post.is_first_post? ? nil : target_post.user_id
      post.extract_quoted_post_numbers
      post.save!
      post.save_reply_relationships
      cleanup_previous_reply_to_relationship(
        post,
        old_reply_to_parent,
        previous_reply_to_post_number
      )
      post.nested_replies_apply_reparent(previous_reply_to_post_number)

      post.reload
      context[:post] = post
      context[:target_post_number] = params.target_post_number
    end

    def cleanup_previous_reply_to_relationship(
      post,
      old_reply_to_parent,
      previous_reply_to_post_number
    )
      return if old_reply_to_parent.blank?

      still_referenced =
        post.reply_to_post_number == previous_reply_to_post_number ||
          post.quoted_post_numbers.include?(previous_reply_to_post_number)
      return if still_referenced

      deleted =
        PostReply.where(
          post_id: old_reply_to_parent.id,
          reply_post_id: post.id
        ).delete_all
      return if deleted == 0
      return if !Topic.visible_post_types.include?(post.post_type)

      Post.where(id: old_reply_to_parent.id).update_all(
        "reply_count = GREATEST(reply_count - 1, 0)"
      )
    end
  end
end
