import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import { i18n } from "discourse-i18n";

export default class MovePostToThreadModal extends Component {
  @tracked targetPostNumber;
  @tracked confirmed = false;
  @tracked saving = false;

  constructor() {
    super(...arguments);

    this.targetPostNumber = this.post.reply_to_post_number || 1;
  }

  get post() {
    return this.args.model.post;
  }

  get topic() {
    return this.args.model.topic;
  }

  get disabled() {
    return (
      this.saving ||
      !this.confirmed ||
      !Number.isInteger(this.normalizedTargetPostNumber) ||
      this.normalizedTargetPostNumber < 1
    );
  }

  get normalizedTargetPostNumber() {
    return Number(this.targetPostNumber);
  }

  get currentLocationLabel() {
    if (this.post.reply_to_post_number) {
      return i18n("discourse_threads.move_post.under_post", {
        post_number: this.post.reply_to_post_number,
      });
    }

    return i18n("discourse_threads.move_post.top_level");
  }

  get targetLocationLabel() {
    if (
      !Number.isInteger(this.normalizedTargetPostNumber) ||
      this.normalizedTargetPostNumber < 1
    ) {
      return i18n("discourse_threads.move_post.choose_target");
    }

    if (this.normalizedTargetPostNumber === 1) {
      return i18n("discourse_threads.move_post.top_level");
    }

    return i18n("discourse_threads.move_post.under_post", {
      post_number: this.normalizedTargetPostNumber,
    });
  }

  @action
  moveToTopLevel() {
    this.targetPostNumber = 1;
  }

  @action
  async movePost() {
    if (this.disabled) {
      return;
    }

    this.saving = true;
    try {
      await ajax(`/threads/topics/${this.topic.id}/posts/${this.post.id}/move`, {
        type: "PUT",
        data: { target_post_number: this.normalizedTargetPostNumber },
      });

      this.args.closeModal();
      this.refreshNestedTopic();
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.saving = false;
    }
  }

  refreshNestedTopic() {
    window.location.assign(`/n/${this.topic.slug}/${this.topic.id}`);
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "discourse_threads.move_post.title"}}
      class="discourse-threads-move-post-modal"
    >
      <:body>
        <div class="discourse-threads-move-post-modal__warning">
          {{i18n "discourse_threads.move_post.warning"}}
        </div>

        <div class="discourse-threads-move-post-modal__summary">
          <div>
            <span class="discourse-threads-move-post-modal__summary-label">
              {{i18n "discourse_threads.move_post.post"}}
            </span>
            <strong>#{{this.post.post_number}}</strong>
          </div>
          <div>
            <span class="discourse-threads-move-post-modal__summary-label">
              {{i18n "discourse_threads.move_post.current_location"}}
            </span>
            <strong>{{this.currentLocationLabel}}</strong>
          </div>
          <div>
            <span class="discourse-threads-move-post-modal__summary-label">
              {{i18n "discourse_threads.move_post.new_location"}}
            </span>
            <strong>{{this.targetLocationLabel}}</strong>
          </div>
        </div>

        <div class="discourse-threads-move-post-modal__target">
          <label class="discourse-threads-move-post-modal__field">
            <span>{{i18n
                "discourse_threads.move_post.target_post_number"
              }}</span>
            <Input
              @type="number"
              @value={{this.targetPostNumber}}
              min="1"
            />
          </label>

          <DButton
            class="btn-default"
            @action={{this.moveToTopLevel}}
            @icon="arrow-up"
            @label="discourse_threads.move_post.make_top_level"
          />
        </div>

        <p class="discourse-threads-move-post-modal__instructions">
          {{i18n "discourse_threads.move_post.instructions"}}
        </p>

        <label class="discourse-threads-move-post-modal__confirm">
          <Input @type="checkbox" @checked={{this.confirmed}} />
          <span>{{i18n "discourse_threads.move_post.confirm"}}</span>
        </label>
      </:body>

      <:footer>
        <DButton
          class="btn-primary discourse-threads-move-post-modal__confirm-button"
          @action={{this.movePost}}
          @disabled={{this.disabled}}
          @label={{if this.saving "saving" "discourse_threads.move_post.action"}}
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
