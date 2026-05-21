export const SCROLL_TARGET_PREFIX = "discourse-threads-scroll-target";

function nodePostNumber(node) {
  return node?.post?.post_number ?? node?.post_number;
}

function nodeChildren(node) {
  return node?.children || [];
}

export function scrollTargetKey(topicId) {
  return `${SCROLL_TARGET_PREFIX}:${topicId}`;
}

export function containsPostNumber(nodes, postNumber) {
  return nodes.some((node) => {
    return (
      nodePostNumber(node) === postNumber ||
      containsPostNumber(nodeChildren(node), postNumber)
    );
  });
}

export function buildContextRootData(contextData) {
  let node = contextData?.target_post;

  if (!node) {
    return null;
  }

  for (let index = (contextData.ancestor_chain || []).length - 1; index >= 0; index--) {
    node = { ...contextData.ancestor_chain[index], children: [node] };
  }

  return node;
}

function mergeNode(existingNode, incomingNode) {
  const incomingChildren = nodeChildren(incomingNode);

  if (incomingChildren.length === 0) {
    return existingNode;
  }

  const mergedChildren = [...nodeChildren(existingNode)];

  for (const incomingChild of incomingChildren) {
    const index = mergedChildren.findIndex(
      (child) => nodePostNumber(child) === nodePostNumber(incomingChild)
    );

    if (index === -1) {
      mergedChildren.push(incomingChild);
    } else {
      mergedChildren[index] = mergeNode(mergedChildren[index], incomingChild);
    }
  }

  return { ...existingNode, children: mergedChildren };
}

export function mergeContextRoot(rootNodes, contextRoot) {
  const rootPostNumber = nodePostNumber(contextRoot);
  const index = rootNodes.findIndex(
    (node) => nodePostNumber(node) === rootPostNumber
  );

  if (index === -1) {
    return [...rootNodes, contextRoot];
  }

  const merged = [...rootNodes];
  merged[index] = mergeNode(merged[index], contextRoot);
  return merged;
}
