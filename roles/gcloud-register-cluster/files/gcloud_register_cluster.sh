#!/bin/bash
#
# Register cluster with fleet and get workload identity
#
#
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

cluster_type="$4"
cluster_name="$5"
project_id="$6"
region="$7"
is_regional_cluster="$8"
if [[ -z "$cluster_type" || -z "$cluster_name" || -z "$project_id" || -z "$region" || -z "$is_regional_cluster=" ]]; then
  echo "Usage: clusterType=standard|autopilot clusterName project_id region isRegionalCluster=0|1"
  exit 1
fi

if [ $is_regional_cluster -eq 1 ]; then
 location_flag="--region $region" 
 cluster_location_isolated="$region"
else
 location_flag="--zone $region-b"
 cluster_location_isolated="$region-b"
fi
echo "location_flag is $location_flag"
echo "cluster_location_isolated is $cluster_location_isolated"

[ -f kubeconfig-${cluster_name} ] || { echo "ERROR could not find kubeconfig-${cluster_name}"; exit 3; }
export KUBECONFIG=$(realpath kubeconfig-${cluster_name})
kubecontext=$(kubectl config current-context)
echo "kubectl current context $kubecontext"

echo "want 'yes' on auth can-i"
kubectl_do_all=$(kubectl auth can-i '*' '*' --all-namespaces)
echo "kubectl auth can-i do all ? $kubectl_do_all"

# check for gcloud login context
gcloud projects list > /dev/null 2>&1
[ $? -eq 0 ] || gcloud auth login --no-launch-browser
gcloud auth list

gcloud config set project $project_id

# workload identity must be enabled
workload_identity=$(gcloud container clusters describe $cluster_name --format="value(workloadIdentityConfig.workloadPool)" $location_flag)
if [ -n "$workload_identity" ]; then
  echo "already have workload identity, no need to register further"
else

  if [ $cluster_type = "autopilot" ]; then
    echo "GKE Autopilot clusters should already have a workload identity.  I would not expect to ever reach this log message"
  else

    # register cluster with Anthos hub, delete any old registration first
    #gcloud container hub memberships delete $cluster_name --quiet
    set -x
    gcloud container hub memberships list
    KUBECONFIG=kubeconfig-membership gcloud container hub memberships register $cluster_name --gke-cluster=$cluster_location_isolated/$cluster_name --enable-workload-identity
    set +x
  
    workload_identity=$(gcloud container clusters describe $cluster_name --format="value(workloadIdentityConfig.workloadPool)" $location_flag)

  fi # if standard GKE cluster, which needs identity


fi # if empty workload identity

[ -n "$workload_identity" ] || { echo "ERROR workload identity must not be enabled for this cluster, see 'gcloud container clusters describe $cluster_name'"; exit 5; }
echo "workload identity: $workload_identity"


