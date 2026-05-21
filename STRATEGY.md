# Discourse Threads - Transition Strategy

## Current direction

`discourse-threads` now builds on Discourse core nested replies instead of shipping a parallel topic renderer.

- Core nested topic URL: `/n/:slug/:topic_id`
- Core nested post URL: `/n/:slug/:topic_id/:post_number`
- Plugin URL: `/threads/:slug/:topic_id`, redirected to `/n/:slug/:topic_id`
- Legacy plugin URL: `/thread/:slug/:topic_id`, also redirected to `/n/:slug/:topic_id`
- Linear Discourse URL: `/t/:slug/:topic_id?flat=1`

The plugin owns the opinionated product layer without patching Discourse core
files:

- Thread mode defaults on for users, unless the admin changes the plugin default.
- Each logged-in user can turn thread mode off per topic. Anonymous users can
  switch the current view to linear mode with `?flat=1`.
- Deep links to nested posts keep the URL unchanged and render the normal full
  tree. If the target post is outside the initial payload, the plugin fetches
  that branch and merges it into the tree before scrolling.
- Topic authors can name up to 10 topic co-managers.
- Topic authors, thread authors, topic co-managers, moderators, and admins can
  relocate posts between nested threads.

## Required settings

Admins must enable core nested replies:

- `nested_replies_enabled`

The plugin setting controls the added thread-mode and manager features:

- `discourse_threads_enabled`
- `discourse_threads_default_thread_mode_enabled`

When both settings are enabled, regular topic JSON includes `is_nested_view` for
users whose default or per-topic preference is thread mode. Discourse's existing
client topic route then routes into `/n/...`. The plugin does not create
`NestedTopic` rows, so core server-side `/t` behavior remains untouched.

## Data model

Per-user topic view preferences live in `discourse_threads_user_topic_preferences`.

Topic co-managers are stored on topics in the JSON custom field:

- `discourse_threads_topic_manager_ids`

The topic creator is always treated as a topic manager. Their ID is not
duplicated in the custom field. Topic payloads serialize the author as a locked
manager so the UI can show that the author cannot be removed.

## Post relocation

Moving a post is implemented as reply-target reparenting inside the plugin
service, so Discourse keeps reply metadata and nested reply stats consistent.
The UI presents this as an orange move icon beside the visible post number,
hidden in linear mode, with a confirmation modal that previews the current and
new thread location. Saving performs a hard reload of `/n/:slug/:topic_id`.

Invalid moves:

- Moving the OP
- Moving under the same post
- Moving under one of the post's descendants
- Moving to a post the actor cannot see
- Moving across topics

Using post number `1` moves the post back to the top level.

## Rollback notes

Disabling `discourse_threads_enabled` removes the switch, manager UI, and move
action. Core nested replies remain controlled by Discourse's
`nested_replies_*` settings.
