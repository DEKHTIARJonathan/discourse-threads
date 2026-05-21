# frozen_string_literal: true

class CreateDiscourseThreadsUserTopicPreferences < ActiveRecord::Migration[8.0]
  def change
    create_table :discourse_threads_user_topic_preferences do |t|
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.boolean :thread_mode_enabled, null: false, default: true
      t.timestamps
    end

    add_index :discourse_threads_user_topic_preferences,
              %i[user_id topic_id],
              unique: true,
              name: "idx_discourse_threads_preferences_user_topic"
    add_index :discourse_threads_user_topic_preferences, %i[topic_id user_id]
  end
end
