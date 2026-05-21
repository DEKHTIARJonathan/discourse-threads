import { module, test } from "qunit";
import {
  buildContextRootData,
  containsPostNumber,
  mergeContextRoot,
  scrollTargetKey,
} from "discourse/plugins/discourse-threads/discourse/lib/discourse-threads-deep-link";

module("Unit | discourse-threads-deep-link", function () {
  test("builds a normal tree branch from context data", function (assert) {
    const root = buildContextRootData({
      ancestor_chain: [
        { post_number: 2 },
        { post_number: 4 },
      ],
      target_post: { post_number: 8, children: [{ post_number: 9 }] },
    });

    assert.deepEqual(root, {
      post_number: 2,
      children: [
        {
          post_number: 4,
          children: [
            { post_number: 8, children: [{ post_number: 9 }] },
          ],
        },
      ],
    });
  });

  test("detects posts in raw and processed trees", function (assert) {
    const rawNodes = [
      { post_number: 2, children: [{ post_number: 3 }] },
    ];
    const processedNodes = [
      { post: { post_number: 4 }, children: [{ post: { post_number: 5 } }] },
    ];

    assert.true(containsPostNumber(rawNodes, 3));
    assert.true(containsPostNumber(processedNodes, 5));
    assert.false(containsPostNumber(processedNodes, 6));
  });

  test("merges a missing context branch into an existing root", function (assert) {
    const rootNodes = [
      {
        post: { post_number: 2 },
        children: [{ post: { post_number: 3 }, children: [] }],
      },
    ];
    const contextRoot = {
      post: { post_number: 2 },
      children: [
        {
          post: { post_number: 4 },
          children: [{ post: { post_number: 5 }, children: [] }],
        },
      ],
    };

    assert.deepEqual(mergeContextRoot(rootNodes, contextRoot), [
      {
        post: { post_number: 2 },
        children: [
          { post: { post_number: 3 }, children: [] },
          {
            post: { post_number: 4 },
            children: [{ post: { post_number: 5 }, children: [] }],
          },
        ],
      },
    ]);
  });

  test("appends a missing root branch and builds stable scroll keys", function (assert) {
    const rootNodes = [{ post: { post_number: 2 }, children: [] }];
    const contextRoot = { post: { post_number: 7 }, children: [] };

    assert.deepEqual(mergeContextRoot(rootNodes, contextRoot), [
      { post: { post_number: 2 }, children: [] },
      { post: { post_number: 7 }, children: [] },
    ]);
    assert.strictEqual(scrollTargetKey(42), "discourse-threads-scroll-target:42");
  });
});
