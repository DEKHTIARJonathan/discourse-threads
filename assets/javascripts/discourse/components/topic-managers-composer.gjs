import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { CREATE_TOPIC } from "discourse/models/composer";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import { i18n } from "discourse-i18n";

export default class TopicManagersComposer extends Component {
  get shouldRender() {
    return (
      this.args.model?.action === CREATE_TOPIC &&
      !this.args.model?.creatingPrivateMessage
    );
  }

  get selectedUsernames() {
    return this.args.model.discourseThreadsTopicManagerUsernames || [];
  }

  @action
  updateManagers(selected) {
    this.args.model.set("discourseThreadsTopicManagerUsernames", selected);
  }

  <template>
    {{#if this.shouldRender}}
      <div class="discourse-threads-composer-managers">
        <label class="discourse-threads-composer-managers__label">
          {{i18n "discourse_threads.topic_managers_optional"}}
        </label>
        <EmailGroupUserChooser
          @value={{this.selectedUsernames}}
          @onChange={{this.updateManagers}}
          @options={{hash
            maximum=10
            filterPlaceholder="discourse_threads.topic_managers_placeholder"
          }}
        />
      </div>
    {{/if}}
  </template>
}
