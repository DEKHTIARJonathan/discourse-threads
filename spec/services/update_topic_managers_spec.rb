# frozen_string_literal: true

RSpec.describe DiscourseThreads::UpdateTopicManagers do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:topic_author, :user)
    fab!(:manager, :user)
    fab!(:topic) { Fabricate(:topic, user: topic_author) }

    let(:params) do
      { topic_id: topic.id, manager_usernames: [manager.username] }
    end
    let(:dependencies) { { guardian: topic_author.guardian } }

    before { SiteSetting.nested_replies_enabled = true }

    context "when contract is invalid" do
      let(:params) { { topic_id: nil, manager_usernames: [] } }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) { { topic_id: 0, manager_usernames: [] } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when nested replies are disabled" do
      before { SiteSetting.nested_replies_enabled = false }

      it { is_expected.to fail_a_policy(:feature_available) }
    end

    context "when the topic is a private message" do
      fab!(:topic) { Fabricate(:private_message_topic, user: topic_author) }

      it { is_expected.to fail_a_policy(:feature_available) }
    end

    context "when user cannot manage the topic" do
      fab!(:other_user, :user)

      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_topic) }
    end

    context "when too many managers are provided" do
      let(:params) do
        {
          topic_id: topic.id,
          manager_usernames:
            Array.new(DiscourseThreads::MAX_TOPIC_MANAGERS + 1) do |index|
              "user#{index}"
            end
        }
      end

      it { is_expected.to fail_a_contract }
    end

    context "when a manager username does not exist" do
      let(:params) do
        { topic_id: topic.id, manager_usernames: ["missing-user"] }
      end

      it { is_expected.to fail_a_step(:resolve_managers) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "stores manager user ids on the topic" do
        result
        expect(DiscourseThreads.manager_ids(topic.reload)).to eq([manager.id])
      end
    end

    context "when the topic author is submitted as a manager" do
      let(:params) do
        {
          topic_id: topic.id,
          manager_usernames: [topic_author.username, manager.username]
        }
      end

      it "keeps the author implicit and stores only co-manager ids" do
        result

        expect(DiscourseThreads.manager_ids(topic.reload)).to eq([manager.id])
        expect(DiscourseThreads.topic_manager_users(topic.reload)).to eq(
          [topic_author, manager]
        )
      end
    end

    context "when the manager is discobot" do
      fab!(:discobot) do
        User.find_by(id: DiscourseNarrativeBot::BOT_USER_ID) ||
          Fabricate(
            :user,
            id: DiscourseNarrativeBot::BOT_USER_ID,
            username: "topicbot",
            username_lower: "topicbot"
          )
      end

      let(:params) do
        { topic_id: topic.id, manager_usernames: [discobot.username] }
      end

      it { is_expected.to run_successfully }

      it "stores the discobot user id on the topic" do
        result
        expect(DiscourseThreads.manager_ids(topic.reload)).to eq([discobot.id])
      end
    end
  end
end
