# Discourse Threads

Threads adds user-facing controls and topic-manager permissions on top of
Discourse core nested replies.

## Admin setup

Enable:

- `nested_replies_enabled`
- `discourse_threads_enabled`

With both enabled, `discourse_threads_default_thread_mode_enabled` controls
whether topics open in thread mode by default. It defaults to on. The plugin
marks regular topic payloads as nested for Discourse's client route without
modifying core controllers or creating core `NestedTopic` rows. Users can switch
an individual topic back to the normal linear Discourse view.

## User workflow

At the top of each topic, users see one thread mode switch in both the nested
and linear views.

- Thread mode opens the nested `/n/...` topic view when enabled and the linear
  `/t/...?flat=1` topic view when disabled for that user and topic.

For logged-in users, the preference is stored per user and per topic. When the
admin default is on, disabling thread mode stores a linear override. When the
admin default is off, enabling thread mode stores a thread override. Anonymous
users can switch the current view to linear mode with `?flat=1`.

Opening `/n/:slug/:topic_id/:post_number` keeps that URL in place. The plugin
loads the normal full nested topic view, fetches the target branch when the post
is outside the initial nested payload, then scrolls to and briefly highlights the
post.

## Topic managers

During topic creation, the creator can choose up to 10 topic co-managers.

After creation, the topic creator, current topic co-managers, moderators, and
admins can edit the manager list from the top-of-topic controls.

The topic author is always displayed as a locked manager and cannot be removed
from the manager role. The editable list only controls additional co-managers.

Topic managers can move replies between nested threads. They do not receive broader moderation powers.

## Moving posts

Authorized users see the visible post number and an orange relocate icon beside
it on movable non-OP posts. The icon is hidden in linear mode.

The relocation modal previews the current and new thread locations and requires
explicit confirmation before saving. Enter the target post number:

- `1` moves the post to the top level.
- Any other visible post number moves the post under that post.

The plugin rejects moves that would create cycles or target invisible posts.
After a successful move, the browser performs a hard reload of the base nested
topic URL so the tree is rebuilt from the server.

## Development

Use the devcontainer for rebuilds and tests:

```bash
bin/rspec plugins/discourse-threads/spec
bin/lint plugins/discourse-threads
```
