import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DiscourseURL from "discourse/lib/url";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class ThreadModeControls extends Component {
  @service currentUser;

  @tracked savingPreference = false;
  @tracked editingManagers = false;
  @tracked savingManagers = false;
  @tracked managerUsernames = null;

  get topic() {
    return this.args.topic;
  }

  get shouldRender() {
    return this.topic?.discourse_threads_available;
  }

  get threadModeEnabled() {
    return (
      !this.topic?._forcedFlat &&
      this.topic?.discourse_threads_thread_mode_enabled !== false
    );
  }

  get toggleLabel() {
    return this.threadModeEnabled
      ? "discourse_threads.switch_to_linear_mode"
      : "discourse_threads.switch_to_thread_mode";
  }

  get managers() {
    return this.topic?.discourse_threads_topic_managers || [];
  }

  get lockedManagers() {
    return this.managers.filter((user) => user.locked);
  }

  get editableManagers() {
    return this.managers.filter((user) => !user.locked);
  }

  get selectedManagerUsernames() {
    if (this.managerUsernames) {
      return this.managerUsernames;
    }

    return this.editableManagers.map((user) => user.username);
  }

  @action
  async toggleThreadMode() {
    if (this.savingPreference) {
      return;
    }

    const enabled = !this.threadModeEnabled;
    this.savingPreference = true;

    try {
      if (!this.currentUser) {
        this.applyThreadMode(enabled);
        return;
      }

      const result = await ajax(`/threads/topics/${this.topic.id}/preference`, {
        type: "PUT",
        data: { thread_mode_enabled: enabled },
      });
      this.topic.set(
        "discourse_threads_thread_mode_enabled",
        result.thread_mode_enabled
      );
      this.applyThreadMode(result.thread_mode_enabled);
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.savingPreference = false;
    }
  }

  applyThreadMode(enabled) {
    if (enabled) {
      this.topic.set("_forcedFlat", false);
      DiscourseURL.routeTo(`/n/${this.topic.slug}/${this.topic.id}`);
    } else {
      this.topic.set("_forcedFlat", true);
      DiscourseURL.routeTo(`/t/${this.topic.slug}/${this.topic.id}?flat=1`);
    }
  }

  @action
  toggleManagerEditor() {
    this.managerUsernames = this.selectedManagerUsernames;
    this.editingManagers = !this.editingManagers;
  }

  @action
  updateManagers(selected) {
    this.managerUsernames = selected;
  }

  @action
  async saveManagers() {
    if (this.savingManagers) {
      return;
    }

    this.savingManagers = true;
    try {
      const result = await ajax(`/threads/topics/${this.topic.id}/managers`, {
        type: "PUT",
        data: { manager_usernames: this.selectedManagerUsernames },
      });
      this.topic.set("discourse_threads_topic_managers", result.managers);
      this.editingManagers = false;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.savingManagers = false;
    }
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-threads-controls">
        <div class="discourse-threads-controls__main">
          <DButton
            class="btn-primary discourse-threads-controls__mode"
            @action={{this.toggleThreadMode}}
            @disabled={{this.savingPreference}}
            @icon={{if this.threadModeEnabled "diagram-project" "list"}}
            @label={{this.toggleLabel}}
          />

          {{#if @topic.discourse_threads_can_manage}}
            <DButton
              class="btn-warning discourse-threads-controls__managers"
              @action={{this.toggleManagerEditor}}
              @icon="user-gear"
              @label="discourse_threads.edit_topic_managers"
            />
          {{/if}}
        </div>

        {{#if this.editingManagers}}
          <div class="discourse-threads-controls__manager-editor">
            {{#if this.lockedManagers.length}}
              <div class="discourse-threads-controls__locked-managers">
                {{#each this.lockedManagers as |manager|}}
                  <span class="discourse-threads-controls__locked-manager">
                    {{manager.username}}
                    <span class="discourse-threads-controls__locked-label">
                      {{i18n "discourse_threads.topic_author_manager"}}
                    </span>
                  </span>
                {{/each}}
              </div>
            {{/if}}
            <EmailGroupUserChooser
              @value={{this.selectedManagerUsernames}}
              @onChange={{this.updateManagers}}
              @options={{hash
                maximum=10
                filterPlaceholder="discourse_threads.topic_managers_placeholder"
              }}
            />
            <DButton
              class="btn-primary"
              @action={{this.saveManagers}}
              @disabled={{this.savingManagers}}
              @label={{if this.savingManagers "saving" "save"}}
            />
          </div>
        {{/if}}

        {{#if this.managers.length}}
          <div class="discourse-threads-controls__manager-list">
            {{i18n "discourse_threads.topic_managers"}}
            {{#each this.managers as |manager index|}}
              {{if index ", "}}{{manager.username}}{{#if manager.owner}}
                {{i18n "discourse_threads.topic_author_badge"}}
              {{/if}}
            {{/each}}
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
