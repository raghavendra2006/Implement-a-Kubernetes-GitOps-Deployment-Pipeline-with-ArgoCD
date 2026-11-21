# Demo Video Guide

## Recording Checklist

This document outlines the demonstration steps for the video recording.

### Setup (1 min)
- Show the repository structure
- Run `./setup-cluster.sh`
- Access ArgoCD UI at https://localhost:30080

### App of Apps Bootstrap (1 min)
- Show root-app.yaml applied
- Show all 6 child applications syncing in ArgoCD UI
- Verify pods running in dev, staging, prod namespaces

### Environment Promotion (2 min)
- Edit `environments/dev/backend-values.yaml` — change image tag or text
- Commit and push
- Show ArgoCD detecting and syncing dev environment
- Copy change to `environments/staging/backend-values.yaml`
- Commit and push
- Show ArgoCD syncing staging

### Configuration Drift & Self-Healing (1 min)
- Run: `kubectl delete svc dev-frontend -n dev`
- Show ArgoCD detecting OutOfSync
- Show service automatically recreated

### Sync Waves & PreSync Hook (1 min)
- Show migration Job running before deployment
- Show wave ordering in ArgoCD sync details

### Rollback (1 min)
- Identify latest commit: `git log --oneline`
- Revert: `git revert HEAD`
- Push and show ArgoCD rolling back

### Notifications (1 min)
- Show webhook.site receiving sync notifications
- Show notification configuration

### Summary (30s)
- Recap all GitOps principles demonstrated
