# frozen_string_literal: true

RSpec.describe DiscourseThreads::ThreadedTopicsController do
  fab!(:user)
  fab!(:topic_author, :user)
  fab!(:topic) { Fabricate(:topic, user: topic_author) }
  fab!(:op) do
    Fabricate(:post, topic: topic, user: topic_author, post_number: 1)
  end
  fab!(:root) do
    Fabricate(:post, topic: topic, post_number: 2, reply_to_post_number: nil)
  end
  fab!(:child) do
    Fabricate(
      :post,
      topic: topic,
      post_number: 3,
      reply_to_post_number: root.post_number
    )
  end
  fab!(:other_root) do
    Fabricate(:post, topic: topic, post_number: 4, reply_to_post_number: nil)
  end
  describe "#show" do
    it "redirects the threads route to the core nested route" do
      get "/threads/#{topic.slug}/#{topic.id}"

      expect(response).to redirect_to("/n/#{topic.slug}/#{topic.id}")
    end

    it "redirects the legacy thread route to the core nested route" do
      get "/thread/#{topic.slug}/#{topic.id}"

      expect(response).to redirect_to("/n/#{topic.slug}/#{topic.id}")
    end

    it "marks regular topic JSON as nested by default for the client route" do
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body["is_nested_view"]).to eq(true)
    end

    it "keeps regular topic JSON linear when thread mode defaults off" do
      SiteSetting.discourse_threads_default_thread_mode_enabled = false

      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body).not_to have_key("is_nested_view")
    end

    it "keeps regular topic JSON linear when the user turned thread mode off" do
      DiscourseThreads::UserTopicPreference.create!(
        user: user,
        topic: topic,
        thread_mode_enabled: false
      )

      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body).not_to have_key("is_nested_view")
    end

    it "serializes locked author manager state and manage permission" do
      topic.custom_fields[DiscourseThreads::TOPIC_MANAGER_IDS_FIELD] = [
        user.id
      ].to_json
      topic.save_custom_fields

      sign_in(user)
      get "/t/#{topic.slug}/#{topic.id}.json"

      expect(response.parsed_body["discourse_threads_can_manage"]).to eq(true)
      expect(
        response.parsed_body["discourse_threads_topic_managers"]
      ).to contain_exactly(
        include("username" => topic_author.username, "locked" => true),
        include("username" => user.username, "locked" => false)
      )
    end

    it "does not expose thread mode controls for private messages" do
      pm_topic =
        Fabricate(:private_message_topic, user: topic_author, recipient: user)

      sign_in(topic_author)
      get "/t/#{pm_topic.slug}/#{pm_topic.id}.json"

      expect(response.parsed_body).not_to have_key("is_nested_view")
      expect(response.parsed_body["discourse_threads_available"]).to eq(false)
      expect(response.parsed_body["discourse_threads_can_manage"]).to eq(false)
      expect(response.parsed_body["discourse_threads_topic_managers"]).to eq([])
    end

    it "does not serialize the OP as movable" do
      sign_in(topic_author)

      get "/t/#{topic.slug}/#{topic.id}.json"

      serialized_op =
        response
          .parsed_body
          .dig("post_stream", "posts")
          .find { |post| post["post_number"] == 1 }
      expect(serialized_op["discourse_threads_can_move"]).to eq(false)
    end

    it "rejects more than ten co-topic managers during topic creation" do
      admin = Fabricate(:admin)
      users =
        Array.new(DiscourseThreads::MAX_TOPIC_MANAGERS + 1) { Fabricate(:user) }
      creator =
        PostCreator.new(
          admin,
          title: "Too many topic managers",
          raw: "This topic has too many submitted co-topic managers.",
          discourse_threads_topic_manager_usernames: users.map(&:username)
        )

      expect(creator.create).to eq(nil)
      expect(creator.errors.full_messages).to include(
        "You can add up to 10 topic co-managers."
      )
    end
  end

  describe "#preference" do
    before { sign_in(user) }

    it "returns the current user's topic mode" do
      DiscourseThreads::UserTopicPreference.create!(
        user: user,
        topic: topic,
        thread_mode_enabled: false
      )

      get "/threads/topics/#{topic.id}/preference.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["thread_mode_enabled"]).to eq(false)
    end

    it "returns not found when the feature is unavailable for the topic" do
      pm_topic =
        Fabricate(:private_message_topic, user: topic_author, recipient: user)

      get "/threads/topics/#{pm_topic.id}/preference.json"

      expect(response.status).to eq(404)
    end

    it "stores the linear-view override" do
      put "/threads/topics/#{topic.id}/preference.json",
          params: {
            thread_mode_enabled: false
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["thread_mode_enabled"]).to eq(false)
      expect(DiscourseThreads.thread_mode_enabled?(user, topic)).to eq(false)
    end

    it "stores the thread-view override when thread mode defaults off" do
      SiteSetting.discourse_threads_default_thread_mode_enabled = false

      put "/threads/topics/#{topic.id}/preference.json",
          params: {
            thread_mode_enabled: true
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["thread_mode_enabled"]).to eq(true)
      expect(DiscourseThreads.thread_mode_enabled?(user, topic)).to eq(true)
    end
  end

  describe "#managers" do
    fab!(:manager, :user)

    before { sign_in(topic_author) }

    it "updates topic managers" do
      put "/threads/topics/#{topic.id}/managers.json",
          params: {
            manager_usernames: [topic_author.username, manager.username]
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body["managers"]).to contain_exactly(
        include("username" => topic_author.username, "locked" => true),
        include("username" => manager.username, "locked" => false)
      )
      expect(DiscourseThreads.manager_ids(topic.reload)).to eq([manager.id])
    end

    it "returns a useful validation error for missing users" do
      put "/threads/topics/#{topic.id}/managers.json",
          params: {
            manager_usernames: ["missing-user"]
          }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        "Topic manager users not found: missing-user"
      )
    end
  end

  describe "#move" do
    it "allows the topic author to move a post" do
      sign_in(topic_author)

      put "/threads/topics/#{topic.id}/posts/#{child.id}/move.json",
          params: {
            target_post_number: other_root.post_number
          }

      expect(response.status).to eq(200)
      expect(child.reload.reply_to_post_number).to eq(other_root.post_number)
    end

    it "rejects regular users" do
      sign_in(user)

      put "/threads/topics/#{topic.id}/posts/#{child.id}/move.json",
          params: {
            target_post_number: other_root.post_number
          }

      expect(response.status).to eq(403)
      expect(child.reload.reply_to_post_number).to eq(root.post_number)
    end
  end
end
