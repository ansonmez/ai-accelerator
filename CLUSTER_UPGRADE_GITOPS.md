# OpenShift Cluster Upgrade with GitOps

Guide for managing ArgoCD/GitOps during OpenShift cluster upgrades.

**Cluster:** ocpair03
**Current Version:** 4.18.27
**Target Version:** 4.19.x
**ArgoCD Applications:** 22 (all with selfHeal: true)

## Recommendation: Minimal to No Pause Needed

For upgrading from 4.18 to 4.19, you generally **DO NOT need to pause GitOps operators**.

### Why It's Safe

1. **OpenShift handles operator compatibility** during upgrades
2. **ArgoCD reconciliation won't interfere** with cluster upgrade process
3. **Certified operators are tested** for upgrade compatibility
4. **Minor version jump** (4.18 → 4.19) has low risk

### When to Consider Pausing

Only if you experience issues with:
- **GPU operator** blocking node drain/upgrade
- **Custom operators** with aggressive reconciliation
- **Previous upgrade problems** with specific operators

---

## Pause/Resume Methods

### Method 1: Disable Auto-Sync for Specific Applications (Recommended)

Temporarily disable automatic sync for specific operator applications.

#### Pause GPU Operator (Example)

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# Disable auto-sync
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Verify
oc get application gpu-operator-certified -n openshift-gitops \
  -o jsonpath='{.spec.syncPolicy.automated}'
# Should return nothing (automated is disabled)
```

#### Resume After Upgrade

```bash
# Re-enable auto-sync
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'

# Verify
oc get application gpu-operator-certified -n openshift-gitops \
  -o jsonpath='{.spec.syncPolicy.automated}'
# Should show: {"prune":false,"selfHeal":true}
```

---

### Method 2: Pause All Operator Applications

Disable auto-sync for all operator applications managed by cluster-operators ApplicationSet.

#### Pause All Operators

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# List all operator applications
OPERATOR_APPS=$(oc get applications -n openshift-gitops \
  -l gitops=operator -o name)

# Disable auto-sync for each
for app in $OPERATOR_APPS; do
  echo "Pausing $app"
  oc patch $app -n openshift-gitops \
    --type merge \
    -p '{"spec":{"syncPolicy":{"automated":null}}}'
done

# Verify
oc get applications -n openshift-gitops -l gitops=operator \
  -o custom-columns=NAME:.metadata.name,AUTO-SYNC:.spec.syncPolicy.automated
```

**Operators Affected:**
- openshift-ai-operator
- openshift-gitops-operator
- openshift-pipelines-operator
- openshift-serverless-operator
- openshift-servicemesh-operator
- gpu-operator-certified
- nfd
- authorino-operator

#### Resume All Operators

```bash
# Re-enable auto-sync for all operator applications
for app in $OPERATOR_APPS; do
  echo "Resuming $app"
  oc patch $app -n openshift-gitops \
    --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'
done

# Verify
oc get applications -n openshift-gitops -l gitops=operator \
  -o custom-columns=NAME:.metadata.name,AUTO-SYNC:.spec.syncPolicy.automated
```

---

### Method 3: Scale Down ApplicationSet Controller (Nuclear Option)

Completely stops ArgoCD from generating/updating applications.

**⚠️ Warning:** This stops ALL ArgoCD automation, not just operators.

#### Pause ApplicationSet Controller

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# Scale to 0 (stops all ApplicationSet processing)
oc scale deployment openshift-gitops-applicationset-controller \
  -n openshift-gitops --replicas=0

# Verify
oc get pods -n openshift-gitops | grep applicationset
# Should show 0 pods
```

#### Resume ApplicationSet Controller

```bash
# Scale back to 1
oc scale deployment openshift-gitops-applicationset-controller \
  -n openshift-gitops --replicas=1

# Verify
oc get pods -n openshift-gitops | grep applicationset
# Should show 1 running pod
```

---

### Method 4: Suspend ArgoCD Application (Per-Application Control)

Mark specific applications as "suspended" to prevent sync.

#### Suspend GPU Operator

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# Suspend application
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}' \
  -p '{"operation":{"initiatedBy":{"automated":false}}}'

# Or use ArgoCD CLI if available
argocd app set gpu-operator-certified --sync-policy none
```

#### Resume

```bash
# Resume application
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'

# Or use ArgoCD CLI
argocd app set gpu-operator-certified --sync-policy automated \
  --self-heal --auto-prune=false
```

---

## Complete Upgrade Procedure with GitOps Pause

### Pre-Upgrade (Optional - Only if Pausing)

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# 1. Take note of current state
oc get clusterversion -o yaml > pre-upgrade-clusterversion.yaml
oc get applications -n openshift-gitops > pre-upgrade-apps.txt

# 2. Pause GPU operator (recommended) or all operators (conservative)
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# 3. Verify pause
oc get application gpu-operator-certified -n openshift-gitops \
  -o jsonpath='{.spec.syncPolicy.automated}'
# Should be empty

# 4. Backup ArgoCD configuration (optional)
oc get applications -n openshift-gitops -o yaml > argocd-apps-backup.yaml
oc get applicationsets -n openshift-gitops -o yaml > argocd-appsets-backup.yaml
```

### Perform Upgrade

```bash
# Check available versions
oc adm upgrade

# Start upgrade to 4.19
oc adm upgrade --to=<version>
# Example: oc adm upgrade --to=4.19.0

# Monitor upgrade
watch -n 30 'oc get clusterversion'
watch -n 30 'oc get nodes'
watch -n 30 'oc get co'  # Cluster operators
```

### Post-Upgrade Resume

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# 1. Verify cluster is healthy
oc get clusterversion
oc get nodes
oc get co  # All cluster operators should be Available=True

# 2. Resume GitOps applications
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'

# Or resume all operators if you paused them all
OPERATOR_APPS=$(oc get applications -n openshift-gitops -l gitops=operator -o name)
for app in $OPERATOR_APPS; do
  oc patch $app -n openshift-gitops \
    --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'
done

# 3. Verify ArgoCD apps sync
oc get applications -n openshift-gitops

# 4. Monitor ArgoCD reconciliation
watch -n 5 'oc get applications -n openshift-gitops'

# 5. Verify operators are healthy
oc get csv -A
oc get pods -n openshift-operators
oc get pods -n redhat-ods-operator
oc get pods -n redhat-ods-applications
```

---

## Monitoring During Upgrade

### Watch Cluster Upgrade Progress

```bash
# Cluster version status
watch -n 30 'oc get clusterversion -o yaml | grep -A 20 "status:"'

# Node upgrade status
watch -n 30 'oc get nodes -o wide'

# Cluster operators health
watch -n 30 'oc get co'

# Check for degraded operators
oc get co | grep -v "True.*False.*False"
```

### Watch ArgoCD Apps (If Not Paused)

```bash
# All applications
watch -n 10 'oc get applications -n openshift-gitops'

# Operator applications only
watch -n 10 'oc get applications -n openshift-gitops -l gitops=operator'

# Check for out-of-sync apps
oc get applications -n openshift-gitops | grep OutOfSync
```

---

## Troubleshooting

### ArgoCD Application Stuck

```bash
# Force refresh
oc patch application <app-name> -n openshift-gitops \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'

# Or delete and let ApplicationSet recreate
oc delete application <app-name> -n openshift-gitops
# Wait a few seconds, ApplicationSet will recreate it
```

### Operator Not Reconciling After Resume

```bash
# Check Application status
oc describe application <app-name> -n openshift-gitops

# Force sync
oc patch application <app-name> -n openshift-gitops \
  --type merge \
  -p '{"operation":{"sync":{"revision":"main"}}}'

# Check operator logs
oc logs -n <operator-namespace> deployment/<operator-name>
```

### GPU Operator Blocking Node Upgrade

```bash
# Check GPU operator status
oc get pods -n gpu-operator-resources

# Pause GPU operator application
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Manually cordon and drain node
oc adm cordon <node-name>
oc adm drain <node-name> --ignore-daemonsets --delete-emptydir-data

# After node upgraded, uncordon
oc adm uncordon <node-name>

# Resume GPU operator
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge \
  -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'
```

---

## Quick Reference

### Check Current State

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03

# Cluster version
oc get clusterversion

# ArgoCD applications
oc get applications -n openshift-gitops

# Check auto-sync status
oc get applications -n openshift-gitops \
  -o custom-columns=NAME:.metadata.name,AUTO-SYNC:.spec.syncPolicy.automated
```

### Pause GPU Operator Only (Recommended)

```bash
# Before upgrade
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

# After upgrade
oc patch application gpu-operator-certified -n openshift-gitops \
  --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'
```

### Resume All If Something Goes Wrong

```bash
# Emergency resume all operator applications
for app in $(oc get applications -n openshift-gitops -l gitops=operator -o name); do
  oc patch $app -n openshift-gitops \
    --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"prune":false,"selfHeal":true}}}}'
done
```

---

## Summary

**My Recommendation for 4.18 → 4.19 Upgrade:**

1. **Don't pause anything** - Just monitor the upgrade
2. **If you want to be cautious** - Pause GPU operator only
3. **Only if paranoid** - Pause all operator applications

**Most likely scenario:** Everything works fine without pausing anything.

**Upgrade duration:** 30-90 minutes typically for minor version upgrade.

**After upgrade:** Verify all operators and applications are healthy, no action needed if you didn't pause.
