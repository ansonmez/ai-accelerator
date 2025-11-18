#!/bin/bash
#
# Cleanup script for ocpair03 GitOps deployment
# This script removes all resources deployed via GitOps including:
# - ArgoCD Applications and ApplicationSets
# - OpenShift AI (RHOAI) operator and resources
# - OpenShift Pipelines operator
# - OpenShift Serverless operator
# - OpenShift Service Mesh operator
# - Authorino operator
# - Custom routes and configurations
#

set -e

KUBECONFIG=${KUBECONFIG:-/root/kubeconfig-ocpair03}
export KUBECONFIG

echo "========================================"
echo "Starting cleanup for ocpair03 cluster"
echo "========================================"
echo ""

# Function to wait for resource deletion
wait_for_deletion() {
    local resource_type=$1
    local resource_name=$2
    local namespace=${3:-""}

    echo "Waiting for $resource_type/$resource_name to be deleted..."
    if [ -n "$namespace" ]; then
        while oc get $resource_type $resource_name -n $namespace &>/dev/null; do
            echo -n "."
            sleep 2
        done
    else
        while oc get $resource_type $resource_name &>/dev/null; do
            echo -n "."
            sleep 2
        done
    fi
    echo " Done!"
}

# Step 1: Delete ArgoCD Applications (this will trigger cascade deletion)
echo "[1/10] Deleting ArgoCD Applications..."
oc delete application.argoproj.io rhoai-gateway-route -n openshift-gitops --ignore-not-found=true
oc delete application.argoproj.io openshift-ai-operator -n openshift-gitops --ignore-not-found=true
oc delete application.argoproj.io openshift-pipelines-operator -n openshift-gitops --ignore-not-found=true
oc delete application.argoproj.io openshift-serverless-operator -n openshift-gitops --ignore-not-found=true
oc delete application.argoproj.io openshift-servicemesh-operator -n openshift-gitops --ignore-not-found=true
oc delete application.argoproj.io authorino-operator -n openshift-gitops --ignore-not-found=true
oc delete application.argoproj.io cluster-config-app-of-apps -n openshift-gitops --ignore-not-found=true

# Step 2: Delete ArgoCD ApplicationSets
echo "[2/10] Deleting ArgoCD ApplicationSets..."
oc delete applicationset.argoproj.io cluster-operators -n openshift-gitops --ignore-not-found=true
oc delete applicationset.argoproj.io cluster-configs -n openshift-gitops --ignore-not-found=true
oc delete applicationset.argoproj.io tenants -n openshift-gitops --ignore-not-found=true

echo "Waiting for Applications to be removed..."
sleep 10

# Step 3: Delete RHOAI DataScienceCluster (must be deleted before operator)
echo "[3/10] Deleting RHOAI DataScienceCluster..."
oc delete datasciencecluster default --ignore-not-found=true --timeout=300s

# Step 4: Delete RHOAI DSCInitialization
echo "[4/10] Deleting RHOAI DSCInitialization..."
oc delete dscinitializations default-dsci --ignore-not-found=true --timeout=300s

# Step 5: Delete RHOAI operator subscription and CSV
echo "[5/10] Deleting RHOAI operator..."
oc delete subscription rhods-operator -n redhat-ods-operator --ignore-not-found=true
oc delete csv -n redhat-ods-operator -l operators.coreos.com/rhods-operator.redhat-ods-operator --ignore-not-found=true

# Step 6: Delete other operator subscriptions
echo "[6/10] Deleting operator subscriptions..."
oc delete subscription openshift-pipelines-operator -n openshift-operators --ignore-not-found=true
oc delete subscription serverless-operator -n openshift-serverless --ignore-not-found=true
oc delete subscription servicemeshoperator3 -n openshift-operators --ignore-not-found=true
oc delete subscription authorino-operator -n openshift-operators --ignore-not-found=true

# Step 7: Delete operator CSVs
echo "[7/10] Deleting operator CSVs..."
oc delete csv -n openshift-operators -l operators.coreos.com/openshift-pipelines-operator.openshift-operators --ignore-not-found=true
oc delete csv -n openshift-serverless -l operators.coreos.com/serverless-operator.openshift-serverless --ignore-not-found=true
oc delete csv -n openshift-operators -l operators.coreos.com/servicemeshoperator3.openshift-operators --ignore-not-found=true
oc delete csv -n openshift-operators -l operators.coreos.com/authorino-operator.openshift-operators --ignore-not-found=true

# Step 8: Delete custom routes
echo "[8/10] Deleting custom routes..."
oc delete route data-science-gateway -n openshift-ingress --ignore-not-found=true

# Step 9: Delete RHOAI namespaces
echo "[9/10] Deleting RHOAI namespaces..."
oc delete namespace redhat-ods-applications --ignore-not-found=true --timeout=300s &
oc delete namespace redhat-ods-monitoring --ignore-not-found=true --timeout=300s &
oc delete namespace redhat-ods-operator --ignore-not-found=true --timeout=300s &
oc delete namespace rhods-notebooks --ignore-not-found=true --timeout=300s &
oc delete namespace rhoai-model-registries --ignore-not-found=true --timeout=300s &
wait

# Step 10: Delete operator-related namespaces
echo "[10/10] Deleting operator namespaces..."
oc delete namespace openshift-serverless --ignore-not-found=true --timeout=300s &
wait

echo ""
echo "========================================"
echo "Cleanup completed!"
echo "========================================"
echo ""
echo "Remaining resources to check manually:"
echo "  - InstallPlans: oc get installplan -n openshift-operators"
echo "  - OperatorGroups: oc get operatorgroup -A"
echo "  - Any finalizers blocking deletion"
echo ""
echo "To verify cleanup:"
echo "  oc get application.argoproj.io -n openshift-gitops"
echo "  oc get subscription.operators.coreos.com -A"
echo "  oc get csv -A | grep -E '(rhods|pipelines|serverless|servicemesh|authorino)'"
echo ""
