import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import MovePostToThreadModal from "discourse/plugins/discourse-threads/discourse/components/modal/move-post-to-thread";

export default class DiscourseThreadsMovePostButton extends Component {
  static shouldRender(args) {
    const topic = args.post?.topic;

    return (
      args.post?.post_number > 1 &&
      args.post?.discourse_threads_can_move &&
      topic?.is_nested_view &&
      topic?._forcedFlat !== true &&
      topic?.discourse_threads_thread_mode_enabled !== false
    );
  }

  @service modal;

  get shouldRender() {
    return this.constructor.shouldRender(this.args);
  }

  @action
  showMoveModal() {
    this.modal.show(MovePostToThreadModal, {
      model: {
        post: this.args.post,
        topic: this.args.post.topic,
      },
    });
  }

  <template>
    {{#if this.shouldRender}}
      <DButton
        class="btn-flat post-action-menu__move-thread discourse-threads-move-post-button"
        ...attributes
        @action={{this.showMoveModal}}
        @icon="up-down-left-right"
        @title="discourse_threads.move_post.button"
      />
    {{/if}}
  </template>
}
