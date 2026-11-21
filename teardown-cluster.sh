#!/usr/bin/env bash
# teardown-cluster.sh — Delete the Kind cluster and clean up
set -euo pipefail

CLUSTER_NAME="gitops-argocd"

echo "============================================"
echo "  GitOps Pipeline — Cluster Teardown"
echo "============================================"
echo ""

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo ">>> Deleting Kind cluster '${CLUSTER_NAME}'..."
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "    ✔ Cluster '${CLUSTER_NAME}' deleted."
else
  echo "    ⚠ Cluster '${CLUSTER_NAME}' does not exist. Nothing to delete."
fi

echo ""
echo "  ✅  Teardown complete."
echo "============================================"
