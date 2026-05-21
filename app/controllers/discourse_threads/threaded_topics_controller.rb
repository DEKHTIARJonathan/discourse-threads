# frozen_string_literal: true

module DiscourseThreads
  class ThreadedTopicsController < ::ApplicationController
    requires_plugin DiscourseThreads::PLUGIN_NAME
    requires_login except: %i[show preference_status]
    skip_before_action :check_xhr, only: [:show]

    def show
      topic = Topic.find_by(id: params[:topic_id].to_i)
      raise Discourse::NotFound if topic.blank? || !guardian.can_see?(topic)

      redirect_to "/n/#{topic.slug}/#{topic.id}", status: :found
    end

    def preference
      UpdateTopicPreference.call(
        service_params.deep_merge(
          params: {
            topic_id: params[:topic_id].to_i,
            thread_mode_enabled:
              ActiveModel::Type::Boolean.new.cast(params[:thread_mode_enabled])
          }
        )
      ) do
        on_success do |params:|
          render json: { thread_mode_enabled: params.thread_mode_enabled }
        end
        on_failed_contract { raise Discourse::InvalidParameters }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_see_topic) { raise Discourse::InvalidAccess }
        on_failure { raise Discourse::InvalidParameters }
      end
    end

    def preference_status
      topic = Topic.find_by(id: params[:topic_id].to_i)
      raise Discourse::NotFound if topic.blank?
      raise Discourse::InvalidAccess if !guardian.can_see?(topic)

      render json: {
               thread_mode_enabled:
                 DiscourseThreads.thread_mode_enabled?(current_user, topic)
             }
    end

    def managers
      UpdateTopicManagers.call(
        service_params.deep_merge(
          params: {
            topic_id: params[:topic_id].to_i,
            manager_usernames: params[:manager_usernames]
          }
        )
      ) do
        on_success do |topic:|
          render json: { managers: serialize_manager_users(topic.reload) }
        end
        on_failed_contract do |contract|
          render_json_error(contract.errors.full_messages, status: :bad_request)
        end
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_failed_policy(:can_manage_topic) { raise Discourse::InvalidAccess }
        on_failure do |missing_usernames: []|
          render_json_error(missing_usernames, status: :unprocessable_entity)
        end
      end
    end

    def move
      MovePostToThread.call(
        service_params.deep_merge(
          params: {
            topic_id: params[:topic_id].to_i,
            post_id: params[:post_id].to_i,
            target_post_number: params[:target_post_number].to_i
          }
        )
      ) do
        on_success do |post:, target_post_number:|
          render json: {
                   post_id: post.id,
                   post_number: post.post_number,
                   reply_to_post_number: post.reply_to_post_number,
                   reply_to_user_id: post.reply_to_user_id,
                   target_post_number: target_post_number
                 }
        end
        on_failed_contract { raise Discourse::InvalidParameters }
        on_model_not_found(:topic) { raise Discourse::NotFound }
        on_model_not_found(:post) { raise Discourse::NotFound }
        on_model_not_found(:target_post) { raise Discourse::NotFound }
        on_failed_policy(:can_relocate_post) { raise Discourse::InvalidAccess }
        on_failed_policy(:post_can_be_moved) do
          raise Discourse::InvalidParameters.new(:post_id)
        end
        on_failed_policy(:valid_target) do
          raise Discourse::InvalidParameters.new(:target_post_number)
        end
        on_failed_policy(:target_is_not_descendant) do
          raise Discourse::InvalidParameters.new(:target_post_number)
        end
        on_failure { raise Discourse::InvalidParameters }
      end
    end

    private

    def serialize_manager_users(topic)
      DiscourseThreads
        .topic_manager_users(topic)
        .map do |user|
          {
            id: user.id,
            username: user.username,
            name: user.name,
            avatar_template: user.avatar_template,
            locked: user.id == topic.user_id,
            owner: user.id == topic.user_id
          }
        end
    end
  end
end
