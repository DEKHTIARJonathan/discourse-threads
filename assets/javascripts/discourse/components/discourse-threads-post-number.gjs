import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";
import DiscourseThreadsMovePostButton from "discourse/plugins/discourse-threads/discourse/components/discourse-threads-move-post-button";

export default class DiscourseThreadsPostNumber extends Component {
  static shouldRender(args) {
    return (
      args.post?.topic?.discourse_threads_available ||
      args.post?.topic?.is_nested_view ||
      args.post?.discourse_threads_can_move
    );
  }

  get postNumber() {
    return this.post.post_number;
  }

  get post() {
    return this.args.outletArgs.post;
  }

  <template>
    <span class="discourse-threads-post-tools">
      <span
        class="discourse-threads-post-number"
        title={{i18n "discourse_threads.post_number_title"}}
      >
        #{{this.postNumber}}
      </span>
      <DiscourseThreadsMovePostButton @post={{this.post}} />
    </span>
  </template>
}
