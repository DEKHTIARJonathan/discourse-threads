import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import ThreadModeControls from "discourse/plugins/discourse-threads/discourse/components/thread-mode-controls";

module("Integration | Component | thread-mode-controls", function (hooks) {
  setupRenderingTest(hooks);

  function topic(attrs = {}) {
    return {
      id: 7,
      slug: "test-topic",
      discourse_threads_available: true,
      discourse_threads_thread_mode_enabled: true,
      discourse_threads_can_manage: false,
      discourse_threads_topic_managers: [],
      set(key, value) {
        this[key] = value;
      },
      ...attrs,
    };
  }

  test("renders the top thread mode control without manager editing for regular users", async function (assert) {
    this.topic = topic();

    await render(<template><ThreadModeControls @topic={{this.topic}} /></template>);

    assert
      .dom(".discourse-threads-controls__mode")
      .hasText("Switch to Linear Mode");
    assert.dom(".discourse-threads-controls__managers").doesNotExist();
  });

  test("renders thread mode action when currently linear", async function (assert) {
    this.topic = topic({ discourse_threads_thread_mode_enabled: false });

    await render(<template><ThreadModeControls @topic={{this.topic}} /></template>);

    assert
      .dom(".discourse-threads-controls__mode")
      .hasText("Switch to Thread Mode");
  });

  test("shows locked topic author when managers can be edited", async function (assert) {
    this.topic = topic({
      discourse_threads_can_manage: true,
      discourse_threads_topic_managers: [
        { username: "author", locked: true, owner: true },
        { username: "manager", locked: false },
      ],
    });

    await render(<template><ThreadModeControls @topic={{this.topic}} /></template>);
    await click(".discourse-threads-controls__managers");

    assert
      .dom(".discourse-threads-controls__locked-manager")
      .hasText("author Topic author");
    assert
      .dom(".discourse-threads-controls__manager-list")
      .includesText("author (author), manager");
  });
});
