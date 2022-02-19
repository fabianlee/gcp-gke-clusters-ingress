#!/bin/bash
#
# Deploy ASM to GKE cluster
#
# in-cluster control plane
# https://cloud.google.com/service-mesh/docs/unified-install/install
# Google managed control plane
# https://cloud.google.com/service-mesh/docs/managed/service-mesh#download_the_installation_tool
#
# Autopilot only supported starting at ASM 1.12+ and requires 'managed' (not incluster) control plane
# because Autopilot does not allow certificate signing requests, which is action taken by istio-system/istiod-asm-1115-3
# https://cloud.google.com/kubernetes-engine/docs/concepts/autopilot-overview#certificate_signing_requests
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

asm_type="$1"
asm_version="$2"
asm_release_channel="$3"
cluster_type="$4"
cluster_name="$5"
project_id="$6"
region="$7"
is_regional_cluster="$8"
if [[ -z "$asm_type" || -z "$asm_version" || -z "$asm_release_channel" || -z "$cluster_type" || -z "$cluster_name" || -z "$project_id" || -z "$region" || -z "$is_regional_cluster=" ]]; then
  echo "Usage: asm_type=managed|incluster asmVersion=1.11 asmReleaseChannel=regular|rapid clusterType=standard|autopilot clusterName project_id region isRegionalCluster=0|1"
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

# ASM downloads
# Most current
#[ -f asmcli ] || curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
# latest <major>.<minor> version
# curl -LO https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.11
#
# latest minor version
[ -f asmcli ] || curl --fail https://storage.googleapis.com/csm-artifacts/asm/asmcli_${asm_version} > asmcli
chmod +x asmcli
./asmcli --version
[ $? -eq 0 ] || { echo "ERROR must have been an error downloading asmcli"; exit 5; }

# check for gcloud login context
gcloud projects list > /dev/null 2>&1
[ $? -eq 0 ] || gcloud auth login --no-launch-browser
gcloud auth list

gcloud config set project $project_id

# services required
xargs -I {} gcloud services enable {} << EOF
container.googleapis.com
compute.googleapis.com
monitoring.googleapis.com
logging.googleapis.com
cloudtrace.googleapis.com
meshca.googleapis.com
meshtelemetry.googleapis.com
meshconfig.googleapis.com
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
[ -n "$workload_identity" ] || { echo "ERROR workload identity must not be enabled for this cluster, see 'gcloud container clusters describe $cluster_name $location_flag'"; exit 5; }
echo "workload identity: $workload_identity"

# check for type that indicates ASM installation has been done
if [ "incluster" = $asm_type ]; then
  kubectl get IstioOperator -n istio-system >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "IstioOperator CRD type existed, but we also need to check if one starting with 'installed-state-asm' exists"
    kubectl get IstioOperator -n istio-system -o=jsonpath="{.items[].metadata.name}" | grep -q installed-state-asm-
  else
    echo "error when trying to read IstioOperator CRD, setting non-zero code for next step"
    $(exit 99)
  fi
elif [ "managed" = "$asm_type" ]; then
  kubectl get Controlplanerevisions -n istio-system 1>/dev/null 2>&1
fi

if [ $? -eq 0 ]; then
  if [ "incluster" = $asm_type ]; then
    echo "IstioOperator is already installed, therefore no need to run asmcli install"
  elif [ "managed" = "$asm_type" ]; then
    echo "Controlplanerevisions is already installed, therefore no need to run asmcli install"
  fi
else
  mkdir -p output-$cluster_name
  echo "asm_type is $asm_type"

  if [ "managed" = $asm_type ]; then

    # https://cloud.google.com/service-mesh/docs/managed/service-mesh#gke_autopilot
    # asm must be in rapid|regular (not stable)
    set -ex
    ./asmcli install \
        --project_id $project_id \
        --cluster_name $cluster_name \
        --fleet_id $project_id \
        --cluster_location $cluster_location_isolated \
        --context $kubecontext \
        --managed \
        --output_dir output-$cluster_name \
        --use_managed_cni \
        --channel $asm_release_channel \
        --enable-all
        # to register correctly,  <projectNum>-compute@developer.gserviceaccount.com needs roles/container.admin role
        #--enable_cluster_roles --enable_cluster_labels --enable_gcp_components \
        #--enable_gcp_apis --enable_gcp_iam_roles
    set +ex

  elif [ "incluster" = $asm_type ]; then

    set -ex
    ./asmcli install \
        --project_id $project_id \
        --cluster_name $cluster_name \
        --fleet_id $project_id \
        --cluster_location $cluster_location_isolated \
        --context $kubecontext \
        --output_dir output-$cluster_name \
        --ca mesh_ca \
        --enable-all
        # to register correctly,  <projectNum>-compute@developer.gserviceaccount.com needs roles/container.admin role
        #--enable_cluster_labels --enable_gcp_components \
        #--enable_cluster_roles --enable_gcp_apis --enable_gcp_iam_roles
    set +ex

  else
    echo "did not recognize asm type (managed|incluster)"
    exit 6
  fi

fi

# show revisions installed
output-$cluster_name/istioctl x revision list

if [ "incluster" = $asm_type ]; then
  echo "Need to configure in-cluster ASM"

  # https://cloud.google.com/architecture/exposing-service-mesh-apps-through-gke-ingress#install_an_ingress_gateway
  #asm_rev_label_from_istiod=$(kubectl get services -n istio-system -l app=istiod -o=jsonpath="{.items[?(@.metadata.labels.istio\.io/rev!='')].metadata}" | jq -r ".labels | .\"istio.io/rev\"" | head -n1)
  asm_rev_label_from_istiod=$(kubectl get deploy -n istio-system -l app=istiod -o jsonpath={.items[*].metadata.labels.'istio\.io\/rev'}'{"\n"}')
  asm_rev_label_from_ns=$(kubectl get ns default -o=jsonpath="{.metadata.labels}" | jq -r ". | .\"istio.io/rev\"")
  [ $asm_rev_label_from_ns = "null" ] && asm_rev_label_from_ns=""
  echo "asm_rev_label_from_istiod = $asm_rev_label_from_istiod"
  echo "asm_rev_label_from_ns = $asm_rev_label_from_ns"

  # associate label with the actual revision
  set -x
  output-$cluster_name/istioctl x revision tag set my-${asm_release_channel} --revision $asm_rev_label_from_istiod --overwrite
  output-$cluster_name/istioctl x revision list
  set +x

  # set ASM revision label for namespace
  for ns in default; do
    kubectl label namespace $ns istio-injection- istio.io/rev=my-${asm_release_channel} --overwrite
  done
  kubectl get ns default --show-labels


elif [ "managed" = $asm_type ]; then

  kubectl get controlplanerevision asm-managed-$asm_release_channel -n istio-system
  if [ $? -ne 0 ]; then
    echo "ERROR with a managed ASM control plane, we would expect a controlplanerevision object"
    exit 7
  else
    echo "ASM already installed into istio-system"
    kubectl get controlplanerevision asm-managed-$asm_release_channel -n istio-system
    echo ""
    reconciled_status=$(kubectl get controlplanerevision asm-managed-$asm_release_channel -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Reconciled')].status}")
    stalled_status=$(kubectl get controlplanerevision asm-managed-$asm_release_channel -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Stalled')].status}")
    echo "ASM control plan reconciled status: $reconciled_status (You want True)"
    echo "ASM control plan stalled status: $stalled_status (You want False)"
  fi
  
  # https://cloud.google.com/service-mesh/docs/managed/service-mesh#managed-data-plane
  echo "creating 'gmanaged-sidecar' namespace where upgraded sidecar are automatically applied"
  kubectl create ns gmanaged-sidecar
  kubectl annotate --overwrite namespace gmanaged-sidecar mesh.cloud.google.com/proxy='{"managed":"true"}'
  if kubectl get dataplanecontrols -o custom-columns=REV:.spec.revision,STATUS:.status.state | grep rapid | grep -v none > /dev/null; then 
    echo "Managed Data Plane is ready."
  else 
    echo "Managed Data Plane is NOT ready."
  fi
  kubectl create deployment nginx-gmanaged -n gmanaged-sidecar --image=nginx:1.21.6
  
  
  # set revision label for namespace
  for ns in default gmanaged-sidecar; do
    kubectl label namespace $ns istio-injection- istio.io/rev=asm-managed-$asm_release_channel --overwrite
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
  name: istio-asm-managed-$asm_release_channel
  namespace: istio-system
EOF

exit 0
