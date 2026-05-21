# frozen_string_literal: true

RSpec.describe DiscourseThreads::MovePostToThread do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
    it { is_expected.to validate_presence_of(:post_id) }
    it { is_expected.to validate_presence_of(:target_post_number) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:topic_author, :user)
    fab!(:root_author, :user)
    fab!(:other_root_author, :user)
    fab!(:topic) { Fabricate(:topic, user: topic_author) }
    fab!(:op) do
      Fabricate(:post, topic: topic, user: topic_author, post_number: 1)
    end
    fab!(:root) do
      Fabricate(
        :post,
        topic: topic,
        user: root_author,
        post_number: 2,
        reply_to_post_number: nil
      )
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
      Fabricate(
        :post,
        topic: topic,
        user: other_root_author,
        post_number: 4,
        reply_to_post_number: nil
      )
    end

    let(:params) do
      {
        topic_id: topic.id,
        post_id: child.id,
        target_post_number: other_root.post_number
      }
    end
    let(:dependencies) { { guardian: topic_author.guardian } }

    before { SiteSetting.nested_replies_enabled = true }

    context "when contract is invalid" do
      let(:params) { { topic_id: nil, post_id: nil, target_post_number: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) do
        {
          topic_id: 0,
          post_id: child.id,
          target_post_number: other_root.post_number
        }
      end

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when user cannot manage the topic" do
      fab!(:other_user, :user)

      let(:dependencies) { { guardian: other_user.guardian } }

      it { is_expected.to fail_a_policy(:can_relocate_post) }
    end

    context "when user is a co-topic manager" do
      fab!(:manager, :user)

      let(:dependencies) { { guardian: manager.guardian } }

      before do
        topic.custom_fields[DiscourseThreads::TOPIC_MANAGER_IDS_FIELD] = [
          manager.id
        ].to_json
        topic.save_custom_fields
      end

      it { is_expected.to run_successfully }
    end

    context "when user created the source thread" do
      let(:dependencies) { { guardian: root_author.guardian } }

      it { is_expected.to run_successfully }
    end

    context "when user created the destination thread" do
      let(:dependencies) { { guardian: other_root_author.guardian } }

      it { is_expected.to run_successfully }
    end

    context "when moving the OP" do
      let(:params) do
        {
          topic_id: topic.id,
          post_id: op.id,
          target_post_number: root.post_number
        }
      end

      it { is_expected.to fail_a_policy(:post_can_be_moved) }
    end

    context "when target is the same post" do
      let(:params) do
        {
          topic_id: topic.id,
          post_id: child.id,
          target_post_number: child.post_number
        }
      end

      it { is_expected.to fail_a_policy(:valid_target) }
    end

    context "when target is a descendant" do
      fab!(:grandchild) do
        Fabricate(
          :post,
          topic: topic,
          post_number: 5,
          reply_to_post_number: child.post_number
        )
      end

      let(:params) do
        {
          topic_id: topic.id,
          post_id: child.id,
          target_post_number: grandchild.post_number
        }
      end

      it { is_expected.to fail_a_policy(:target_is_not_descendant) }
    end

    context "when moving under another root" do
      it { is_expected.to run_successfully }

      it "updates the reply target" do
        expect { result }.to change { child.reload.reply_to_post_number }.from(
          root.post_number
        ).to(other_root.post_number)
      end
    end

    context "when moving to the top level" do
      let(:params) do
        {
          topic_id: topic.id,
          post_id: child.id,
          target_post_number: op.post_number
        }
      end

      it { is_expected.to run_successfully }

      it "clears the reply target" do
        expect { result }.to change { child.reload.reply_to_post_number }.from(
          root.post_number
        ).to(nil)
      end
    end
  end
end
