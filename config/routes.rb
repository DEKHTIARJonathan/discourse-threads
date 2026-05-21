# frozen_string_literal: true

DiscourseThreads::Engine.routes.draw do
  get "/topics/:topic_id/preference" => "threaded_topics#preference_status"
  put "/topics/:topic_id/preference" => "threaded_topics#preference"
  put "/topics/:topic_id/managers" => "threaded_topics#managers"
  put "/topics/:topic_id/posts/:post_id/move" => "threaded_topics#move"
  get "/:slug/:topic_id" => "threaded_topics#show"
end
