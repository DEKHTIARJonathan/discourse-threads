# frozen_string_literal: true

RSpec.describe DiscourseThreads::UpdateTopicPreference do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:topic_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:user)
    fab!(:topic)

    let(:params) { { topic_id: topic.id, thread_mode_enabled: } }
    let(:dependencies) { { guardian: user.guardian } }
    let(:thread_mode_enabled) { false }

    before { SiteSetting.nested_replies_enabled = true }

    context "when contract is invalid" do
      let(:params) { { topic_id: nil, thread_mode_enabled: false } }

      it { is_expected.to fail_a_contract }
    end

    context "when topic is not found" do
      let(:params) { { topic_id: 0, thread_mode_enabled: false } }

      it { is_expected.to fail_to_find_a_model(:topic) }
    end

    context "when nested replies are disabled" do
      before { SiteSetting.nested_replies_enabled = false }

      it { is_expected.to fail_a_policy(:feature_available) }
    end

    context "when the topic is a private message" do
      fab!(:topic) { Fabricate(:private_message_topic, user: user) }

      it { is_expected.to fail_a_policy(:feature_available) }
    end

    context "when disabling thread mode" do
      it { is_expected.to run_successfully }

      it "stores the user topic preference" do
        expect { result }.to change {
          DiscourseThreads::UserTopicPreference.where(
            user: user,
            topic: topic,
            thread_mode_enabled: false
          ).count
        }.from(0).to(1)
      end
    end

    context "when enabling thread mode" do
      let(:thread_mode_enabled) { true }

      before do
        DiscourseThreads::UserTopicPreference.create!(
          user: user,
          topic: topic,
          thread_mode_enabled: false
        )
      end

      it { is_expected.to run_successfully }

      it "removes the stored override" do
        expect { result }.to change {
          DiscourseThreads::UserTopicPreference.where(
            user: user,
            topic: topic
          ).count
        }.from(1).to(0)
      end
    end

    context "when thread mode defaults off" do
      before do
        SiteSetting.discourse_threads_default_thread_mode_enabled = false
      end

      context "when enabling thread mode" do
        let(:thread_mode_enabled) { true }

        it "stores the user topic preference" do
          expect { result }.to change {
            DiscourseThreads::UserTopicPreference.where(
              user: user,
              topic: topic,
              thread_mode_enabled: true
            ).count
          }.from(0).to(1)
        end
      end

      context "when disabling thread mode" do
        let(:thread_mode_enabled) { false }

        before do
          DiscourseThreads::UserTopicPreference.create!(
            user: user,
            topic: topic,
            thread_mode_enabled: true
          )
        end

        it "removes the stored override" do
          expect { result }.to change {
            DiscourseThreads::UserTopicPreference.where(
              user: user,
              topic: topic
            ).count
          }.from(1).to(0)
        end
      end
    end
  end
end
