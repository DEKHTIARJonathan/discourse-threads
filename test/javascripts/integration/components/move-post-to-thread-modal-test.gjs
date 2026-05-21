import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import MovePostToThreadModal from "discourse/plugins/discourse-threads/discourse/components/modal/move-post-to-thread";

module("Integration | Component | move-post-to-thread-modal", function (hooks) {
  setupRenderingTest(hooks);

  test("requires explicit confirmation before relocating", async function (assert) {
    this.model = {
      topic: { id: 7, slug: "test-topic" },
      post: { id: 12, post_number: 3, reply_to_post_number: 2 },
    };
    this.closeModal = () => {};

    await render(
      <template>
        <MovePostToThreadModal
          @model={{this.model}}
          @closeModal={{this.closeModal}}
        />
      </template>
    );

    assert
      .dom(".discourse-threads-move-post-modal__warning")
      .hasText("Relocating changes where this post appears in the thread tree.");
    assert
      .dom(".discourse-threads-move-post-modal__confirm-button")
      .isDisabled();
    assert.dom(".discourse-threads-move-post-modal__field input").hasValue("2");

    await fillIn(".discourse-threads-move-post-modal__field input", "4");
    await click(".discourse-threads-move-post-modal__confirm input");

    assert
      .dom(".discourse-threads-move-post-modal__summary")
      .includesText("Under post #4");
    assert
      .dom(".discourse-threads-move-post-modal__confirm-button")
      .isEnabled();
  });
});
