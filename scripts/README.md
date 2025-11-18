# Cleanup Scripts

## cleanup-ocpair03.sh

This script performs a complete cleanup of all resources deployed via GitOps on the ocpair03 cluster.

### What it removes:

1. **ArgoCD Applications and ApplicationSets**
   - All operator Applications (RHOAI, Pipelines, Serverless, Service Mesh, Authorino)
   - Gateway route Application
   - Cluster config Applications

2. **RHOAI Resources**
   - DataScienceCluster
   - DSCInitialization
   - RHOAI operator subscription and CSV
   - RHOAI namespaces (redhat-ods-applications, redhat-ods-operator, redhat-ods-monitoring, rhods-notebooks, rhoai-model-registries)

3. **Operator Subscriptions and CSVs**
   - OpenShift Pipelines
   - OpenShift Serverless
   - OpenShift Service Mesh 3
   - Authorino

4. **Custom Routes**
   - data-science-gateway route

5. **Namespaces**
   - All RHOAI-related namespaces
   - openshift-serverless namespace

### Usage:

```bash
# Set KUBECONFIG if not already set
export KUBECONFIG=/root/kubeconfig-ocpair03

# Run the cleanup script
./scripts/cleanup-ocpair03.sh
```

### What is NOT removed:

- OpenShift GitOps (ArgoCD) itself
- ArgoCD Projects
- CRDs installed by operators
- istio-system namespace and Istio Gateway CRDs
- Any resources not deployed via this GitOps project

### After cleanup:

To start fresh, run:
```bash
oc apply -k clusters/overlays/ocpair03
```

### Verification:

After running the cleanup, verify with:
```bash
# Check no Applications remain
oc get application.argoproj.io -n openshift-gitops

# Check no operator subscriptions remain
oc get subscription.operators.coreos.com -A

# Check no operator CSVs remain
oc get csv -A | grep -E '(rhods|pipelines|serverless|servicemesh|authorino)'

# Check InstallPlans
oc get installplan -n openshift-operators
```

### Troubleshooting:

If resources are stuck in "Terminating" state:

1. **Check for finalizers:**
   ```bash
   oc get <resource-type> <resource-name> -o yaml | grep -A5 finalizers
   ```

2. **Remove finalizers (use with caution):**
   ```bash
   oc patch <resource-type> <resource-name> --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]'
   ```

3. **Force delete namespace:**
   ```bash
   oc delete namespace <namespace> --force --grace-period=0
   ```
