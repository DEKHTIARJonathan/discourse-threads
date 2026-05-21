import { later, schedule } from "@ember/runloop";
import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import processNode from "discourse/lib/process-node";
import DiscourseThreadsPostNumber from "discourse/plugins/discourse-threads/discourse/components/discourse-threads-post-number";
import {
  buildContextRootData,
  containsPostNumber,
  mergeContextRoot,
  scrollTargetKey,
} from "discourse/plugins/discourse-threads/discourse/lib/discourse-threads-deep-link";

function scrollToStoredTarget(topicId, attempt = 0) {
  const key = scrollTargetKey(topicId);
  const postNumber = window.sessionStorage.getItem(key);

  if (!postNumber) {
    return;
  }

  const target = document.querySelector(
    `.nested-view [data-post-number="${postNumber}"]`
  );

  if (!target) {
    if (attempt < 20) {
      later(() => scrollToStoredTarget(topicId, attempt + 1), 150);
    }
    return;
  }

  window.sessionStorage.removeItem(key);
  target.scrollIntoView({ block: "center" });

  const post = target.closest(".nested-post");
  post?.classList.add("nested-post--highlighted");
  later(() => post?.classList.remove("nested-post--highlighted"), 2000);
}

export default {
  name: "discourse-threads",

  initialize(container) {
    const siteSettings = container.lookup("service:site-settings");

    if (!siteSettings.discourse_threads_enabled) {
      return;
    }

    withPluginApi((api) => {
      const router = container.lookup("service:router");

      api.serializeOnCreate(
        "discourse_threads_topic_manager_usernames",
        "discourseThreadsTopicManagerUsernames"
      );

      api.renderAfterWrapperOutlet(
        "post-metadata",
        DiscourseThreadsPostNumber
      );

      api.modifyClass("route:nested-post", {
        pluginId: "discourse-threads",

        async model(params) {
          const { slug, topic_id, post_number } = params;
          const sort =
            params.sort || this.siteSettings.nested_replies_default_sort || "top";
          const [data, contextData] = await Promise.all([
            ajax(`/n/${slug}/${topic_id}.json?sort=${sort}&track_visit=true`),
            ajax(`/n/${slug}/${topic_id}/context/${post_number}.json?sort=${sort}`),
          ]);
          const model = this._processResponse(data, params);

          if (!containsPostNumber(model.rootNodes, Number(post_number))) {
            const contextRootData = buildContextRootData(contextData);

            if (contextRootData) {
              model.rootNodes = mergeContextRoot(
                model.rootNodes,
                processNode(this.store, model.topic, contextRootData)
              );
            }
          }

          window.sessionStorage.setItem(
            scrollTargetKey(topic_id),
            post_number
          );

          return model;
        },
      });

      router.on("routeDidChange", (transition) => {
        if (["nested", "nestedPost"].includes(transition.to?.name)) {
          schedule("afterRender", () => {
            scrollToStoredTarget(transition.to.params.topic_id);
          });
        }
      });
    });
  },
};
