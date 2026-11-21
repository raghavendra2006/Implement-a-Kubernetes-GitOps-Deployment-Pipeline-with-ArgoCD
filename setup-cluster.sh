#!/usr/bin/env bash
# setup-cluster.sh — Bootstrap a Kind cluster with ArgoCD and GitOps pipeline
set -euo pipefail

CLUSTER_NAME="gitops-argocd"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_REPO_URL="${GIT_REPO_URL:-https://github.com/raghavendra2006/Implement-a-Kubernetes-GitOps-Deployment-Pipeline-with-ArgoCD.git}"

echo "============================================"
echo "  GitOps Pipeline — Cluster Setup"
echo "============================================"

# --------------------------------------------------
# 1. Create Kind cluster
# --------------------------------------------------
echo ""
echo ">>> Creating Kind cluster '${CLUSTER_NAME}'..."
if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  echo "    Cluster '${CLUSTER_NAME}' already exists. Deleting first..."
  kind delete cluster --name "${CLUSTER_NAME}"
fi
kind create cluster --name "${CLUSTER_NAME}" --config "${SCRIPT_DIR}/kind-config.yaml" --wait 120s
echo "    ✔ Cluster created."

# --------------------------------------------------
# 2. Create argocd namespace
# --------------------------------------------------
echo ""
echo ">>> Creating 'argocd' namespace..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
echo "    ✔ Namespace 'argocd' ready."

# --------------------------------------------------
# 3. Install ArgoCD via official stable manifests
# --------------------------------------------------
echo ""
echo ">>> Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "    ✔ ArgoCD manifests applied."

# --------------------------------------------------
# 4. Wait for ArgoCD pods to be ready
# --------------------------------------------------
echo ""
echo ">>> Waiting for ArgoCD pods to be ready (timeout 300s)..."
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-repo-server \
  -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-redis \
  -n argocd --timeout=300s
kubectl wait --for=condition=available deployment/argocd-dex-server \
  -n argocd --timeout=300s || true
echo "    ✔ ArgoCD pods are ready."

# --------------------------------------------------
# 5. Patch argocd-server to NodePort on port 30080
# --------------------------------------------------
echo ""
echo ">>> Patching argocd-server service to NodePort (30080)..."
kubectl patch svc argocd-server -n argocd -p '{
  "spec": {
    "type": "NodePort",
    "ports": [
      {
        "name": "http",
        "port": 80,
        "targetPort": 8080,
        "nodePort": 30080,
        "protocol": "TCP"
      },
      {
        "name": "https",
        "port": 443,
        "targetPort": 8080,
        "nodePort": 30443,
        "protocol": "TCP"
      }
    ]
  }
}'
echo "    ✔ argocd-server patched to NodePort."

# --------------------------------------------------
# 6. Retrieve and print initial admin password
# --------------------------------------------------
echo ""
echo ">>> Retrieving ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "    ✔ Admin password retrieved."

# --------------------------------------------------
# 7. Create dev, staging, prod namespaces
# --------------------------------------------------
echo ""
echo ">>> Creating application namespaces..."
for NS in dev staging prod; do
  kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -
  echo "    ✔ Namespace '${NS}' ready."
done

# --------------------------------------------------
# 8. Apply custom ArgoCD ConfigMaps & Secrets
# --------------------------------------------------
echo ""
echo ">>> Applying ArgoCD configuration..."
kubectl apply -f "${SCRIPT_DIR}/argocd-config/argocd-cm.yaml"
echo "    ✔ argocd-cm ConfigMap applied."

kubectl apply -f "${SCRIPT_DIR}/argocd-config/argocd-notifications-cm.yaml"
echo "    ✔ argocd-notifications-cm ConfigMap applied."

kubectl apply -f "${SCRIPT_DIR}/argocd-config/argocd-notifications-secret.yaml"
echo "    ✔ argocd-notifications-secret Secret applied."

# Restart argocd-server to pick up config changes
echo ""
echo ">>> Restarting argocd-server to pick up configuration..."
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s
echo "    ✔ argocd-server restarted."

# --------------------------------------------------
# 9. Register the git repository with ArgoCD
# --------------------------------------------------
echo ""
echo ">>> Registering Git repository with ArgoCD..."
kubectl apply -n argocd -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: repo-gitops-pipeline
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: "${GIT_REPO_URL}"
EOF
echo "    ✔ Git repository registered."

# --------------------------------------------------
# 10. Apply root-app.yaml (App of Apps bootstrap)
# --------------------------------------------------
echo ""
echo ">>> Applying root-app.yaml (App of Apps bootstrap)..."
kubectl apply -f "${SCRIPT_DIR}/root-app.yaml"
echo "    ✔ Root application applied."

# --------------------------------------------------
# 11. Print access instructions
# --------------------------------------------------
echo ""
echo "============================================"
echo "  ✅  Setup Complete!"
echo "============================================"
echo ""
echo "  ArgoCD UI:       https://localhost:30080"
echo "  Username:        admin"
echo "  Password:        ${ARGOCD_PASSWORD}"
echo ""
echo "  Namespaces:      argocd, dev, staging, prod"
echo "  Cluster:         ${CLUSTER_NAME}"
echo ""
echo "  Useful commands:"
echo "    kubectl get apps -n argocd"
echo "    kubectl get pods -n argocd"
echo "    argocd login localhost:30080 --insecure --username admin --password '${ARGOCD_PASSWORD}'"
echo ""
echo "  To tear down:    bash ${SCRIPT_DIR}/teardown-cluster.sh"
echo "============================================"
