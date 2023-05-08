#!/bin/bash
#
# Deploy ASM to GKE cluster using 'gcloud container fleet mesh update'
# does not require asmcli
# https://cloud.google.com/service-mesh/docs/managed/provision-managed-anthos-service-mesh
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

cluster_type="$1"
cluster_name="$2"
project_id="$3"
region="$4"
is_regional_cluster="$5"
if [[ -z "$cluster_type" || -z "$cluster_name" || -z "$project_id" || -z "$region" || -z "$is_regional_cluster" ]]; then
  echo "Usage: cluserType=managed|incluster clusterName project_id region isRegionalCluster=0|1"
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
auth_cani=$(kubectl auth can-i '*' '*' --all-namespaces)
echo "auth_cani do all ? $auth_cani"

# check for gcloud login context
gcloud projects list > /dev/null 2>&1
[ $? -eq 0 ] || gcloud auth login --no-launch-browser
gcloud auth list

gcloud config set project $project_id
project_number=$(gcloud projects list --filter="id=$project_id" --format="value(projectNumber)")
echo "project_number: $project_number"

# services required
xargs -I {} gcloud services enable {} << EOF
container.googleapis.com
compute.googleapis.com
monitoring.googleapis.com
logging.googleapis.com
cloudtrace.googleapis.com
mesh.googleapis.com
iamcredentials.googleapis.com
gkeconnect.googleapis.com
gkehub.googleapis.com
cloudresourcemanager.googleapis.com
stackdriver.googleapis.com
EOF

echo "Make sure KUBECONFIG $KUBECONFIG is usable"
set -ex
kubectl get nodes -o wide
set +ex

# namespace where ASM is installed
kubectl create ns istio-system

# make sure GKE cluster meets requirements of 1.21.3+ for GKE Autopilot
cluster_min_allowed_version="v1.21.3"
if [ $cluster_type = "autopilot" ]; then

  # autopilot nodes will not return node list via kubectl, so use kubectl as fallback
  worker_node_version=$(kubectl get nodes -o=jsonpath="{.items[].status.nodeInfo.kubeletVersion}")
  [ -n "$worker_node_version" ] || worker_node_version=$(kubectl version 2>/dev/null | grep 'Server Version' | grep -Po "GitVersion:\"(.*?)\"" | cut -d: -f2 | tr -d '"')

  if [[ "$worker_node_version" < "$cluster_min_allowed_version" ]]; then
    echo "ERROR actual worker node version $worker_node_version is < minimal required $cluster_min_allowed_version"
    exit 5
  else
    echo "GOOD actual worker node version $worker_node_version is >= minimal required $cluster_min_allowed_version"
  fi
fi


# https://cloud.google.com/service-mesh/v1.7/docs/private-cluster-open-port
# port 15017 must be open for private GKE clusters so auto-injection works
firewall_rule_name=$(gcloud compute firewall-rules list --filter="name~gke-${cluster_name}-[0-9a-z]*-master" --format="value(name)")
echo "firewall rule that needs port 15017 added for ASM auto-injection"
gcloud compute firewall-rules update $firewall_rule_name --allow tcp:10250,tcp:443,tcp:15017,tcp:15014,tcp:8080

# validate valid KUBECONFIG
kubectl get nodes
[ $? -eq 0 ] || { echo "ERROR do you have a valid KUBECONFIG at $KUBECONFIG ?"; exit 3; }


# workload identity must be enabled
workload_identity=$(gcloud container clusters describe $cluster_name --format="value(workloadIdentityConfig.workloadPool)" $location_flag)
[ -n "$workload_identity" ] || { echo "ERROR workload identity is not be enabled for this cluster, see 'gcloud container clusters describe $cluster_name $location_flag'"; exit 5; }
echo "workload identity: $workload_identity"


# check for type that indicates ASM installation has been done
asm_already_installed=0
# not good enough to validate installation, need valid object type with at least 1 result
kubectl get controlplanerevisions -n istio-system 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "controlplanerevisions CRD object is valid, but find actual object now"

  cplane_name=$(kubectl get controlplanerevision -n istio-system --output="jsonpath={.items[0].metadata.name}")
  echo "control plane name: $cplane_name"
  reconciled_status=$(kubectl get controlplanerevision $cplane_name -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Reconciled')].status}")

  if [ -z "$cplane_name" ]; then
    $(exit 99)
  fi
else
  # pass along error code
  $(exit 1)
fi

if [ -n "$cplane_name" ]; then
  echo "controlplanerevisions '$cplane_name' is already installed, therefore skipping install"
else

    # using gcloud fleet installation for managed ASM (instead of asmcli)
    # https://cloud.google.com/service-mesh/docs/managed/provision-managed-anthos-service-mesh#limitations
    gke_uri=$(gcloud container clusters list --uri --filter="name=$cluster_name")
    echo "gke_uri: $gke_uri"
    set -x
    gcloud container fleet mesh enable --project $project_id
    gcloud container fleet memberships register $cluster_name --gke-uri=$gke_uri --enable-workload-identity --project $project_id
    gcloud container fleet mesh update --management automatic --memberships $cluster_name --project $project_id
    gcloud container clusters update $cluster_name --project $project_id $location_flag --update-labels mesh_id=proj-${project_number}
    set +x

    # wait for reconciled status which indicates done
    waiting_for_status=1
    while [[ $waiting_for_status -eq 1 ]]; do
      reconciled_status=$(kubectl get controlplanerevision $cplane_name -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Reconciled')].status}")
      stalled_status=$(kubectl get controlplanerevision $cplane_name -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Stalled')].status}")

      # if we see a proper reconcile or a stall, then exit wait loop
      if [[ "$reconciled_status" == "True" || "$stalled_status" == "True" ]]; then
        waiting_for_status=0
      fi
      sleep 3

    done 

fi

# controlplanerevision should now exist at this point in script
# check status of reconciliation, which signals installation complete
kubectl get controlplanerevision $cplane_name -n istio-system 1>/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "ERROR finding managed ASM control plane, we would expect a controlplanerevision object"
  exit 7
else
  echo "managed ASM already installed into istio-system"
  reconciled_status=$(kubectl get controlplanerevision $cplane_name -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Reconciled')].status}")
  stalled_status=$(kubectl get controlplanerevision $cplane_name -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Stalled')].status}")
  echo "ASM control plan reconciled status: $reconciled_status (You want True)"
  echo "ASM control plan stalled status: $stalled_status (You want False)"
fi

# test sidecar proxy if ASM reconciled
kubectl get deployment/nginx-gmanaged -n gmanaged-sidecar 2>/dev/null 1>&2
if [[ $? -eq 0 ]]; then
  echo "Already created gmanaged-sidecar deployment"
elif [[ "$reconciled_status" != "True" ]]; then
  echo "Skipping sidecard test because reconcilation of $cplane_name not complete $reconciled_status"
elif [ "$reconciled_status" == "True" ]; then
  # https://cloud.google.com/service-mesh/docs/managed/service-mesh#managed-data-plane
  echo "creating 'gmanaged-sidecar' namespace where upgraded sidecar are automatically applied"
  kubectl create ns gmanaged-sidecar
  kubectl label namespace $ns istio-injection- istio.io/rev=$cplane_name --overwrite
  kubectl annotate --overwrite namespace gmanaged-sidecar mesh.cloud.google.com/proxy='{"managed":"true"}'
  if kubectl get dataplanecontrols -o custom-columns=REV:.spec.revision,STATUS:.status.state | grep rapid | grep -v none > /dev/null; then 
    echo "Managed Data Plane is ready."
  else 
    echo "Managed Data Plane is NOT ready."
  fi
  kubectl create deployment nginx-gmanaged -n gmanaged-sidecar --image=nginx:1.21.6
fi


if [ "$reconciled_status" == "True" ]; then
  # delete webhook that continues to cause virtualservice creation to fail
  # failed to call webhook: Post https://meshconfig.googleapis.com/v1alpha1/...
  kubectl delete Validatingwebhookconfigurations istiod-istio-system-mcp -n istio-system

  # set revision label for default namespace
  for ns in default; do
    kubectl label namespace $ns istio-injection- istio.io/rev=$cplane_name --overwrite
  done
  kubectl get ns istio-system --show-labels
fi
  
  # https://cloud.google.com/service-mesh/docs/managed/optional-features#enable_cloud_tracing
echo "Enable cloud tracing..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
data:
  mesh: |-
    defaultConfig:
      tracing:
        stackdriver:{}
kind: ConfigMap
metadata:
  name: istio-$cplane_name
  namespace: istio-system
EOF

exit 0
