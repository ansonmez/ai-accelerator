# ocpair03 Cluster Configuration

**Cluster Name:** ocpair03
**RHOAI Version:** 2.25.0 (stable-2.25 channel)
**Created:** 2025-11-17
**Purpose:** Production RHOAI cluster

## Configuration

- OpenShift AI: v2.25 (stable-2.25 channel)
- OpenShift GitOps: v1.18
- OpenShift Pipelines: v1.20
- OpenShift Serverless: v1.36
- OpenShift Service Mesh: v2.6

## Custom ApplicationSets

- llama-stack (Llama Stack AI services)
- open5gs (5G Core Network)
- ueransim (5G RAN Simulator)

## Deployment Command

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03
oc apply -k clusters/overlays/ocpair03
```

## Monitoring Upgrade

```bash
# Watch subscription update
oc get subscription rhods-operator -n redhat-ods-operator -w

# Watch CSV upgrade
oc get csv -n redhat-ods-operator -w

# Verify final version
oc get csv -n redhat-ods-operator | grep rhods-operator
```

## Rollback to 2.19

If issues occur, rollback by applying the previous overlay:

```bash
export KUBECONFIG=/root/kubeconfig-ocpair03
oc apply -k clusters/overlays/rhoai-stable-2.19
```

## Version History

- 2025-11-17: Upgraded to RHOAI 2.25 (stable-2.25 channel)
- Previous: RHOAI 2.19 (stable-2.19 channel)
