import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DiscourseThreadsMovePostButton from "discourse/plugins/discourse-threads/discourse/components/discourse-threads-move-post-button";

module("Integration | Component | discourse-threads-move-post-button", function (hooks) {
  setupRenderingTest(hooks);

  test("renders for movable posts without requiring topic availability on the post model", async function (assert) {
    this.post = {
      id: 12,
      post_number: 3,
      discourse_threads_can_move: true,
      topic: { id: 7, slug: "test-topic", is_nested_view: true },
    };

    await render(
      <template><DiscourseThreadsMovePostButton @post={{this.post}} /></template>
    );

    assert.dom(".discourse-threads-move-post-button").exists();
    assert.dom(".discourse-threads-move-post-button .d-icon").exists();
    assert.dom(".discourse-threads-move-post-button .d-button-label").doesNotExist();
  });

  test("does not render in linear mode", async function (assert) {
    this.post = {
      id: 12,
      post_number: 3,
      discourse_threads_can_move: true,
      topic: {
        id: 7,
        slug: "test-topic",
        is_nested_view: false,
        discourse_threads_thread_mode_enabled: false,
      },
    };

    await render(
      <template><DiscourseThreadsMovePostButton @post={{this.post}} /></template>
    );

    assert.dom(".discourse-threads-move-post-button").doesNotExist();
  });
});
