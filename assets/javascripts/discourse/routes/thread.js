import Route from "@ember/routing/route";
import { service } from "@ember/service";

export default class ThreadRoute extends Route {
  @service router;

  beforeModel(transition) {
    const { slug, topic_id } = transition.to.params;
    this.router.replaceWith("nested", slug, topic_id);
  }
}
