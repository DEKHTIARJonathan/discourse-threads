export default function () {
  this.route("threads", { path: "/threads/:slug/:topic_id" });
  this.route("thread", { path: "/thread/:slug/:topic_id" });
}
