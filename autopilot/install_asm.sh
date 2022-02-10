#!/bin/bash
#
# Install ASM into GKE cluster
#
# in-cluster control plane
# https://cloud.google.com/service-mesh/docs/unified-install/install
# Google managed control plane
# https://cloud.google.com/service-mesh/docs/managed/service-mesh#download_the_installation_tool
#
# usage: gkeClusterType=autopilot|standard asmType=managed|incluster asmVersion=1.11|1.12
#

cluster_type="${1:-autopilot}"
[[ "autopilot standard " =~ $cluster_type[[:space:]] ]] || { echo "ERROR only valid types are standard|autopilot"; exit 3; }

[ $cluster_type = "autopilot" ] && cluster_name="autopilot-cluster1" || cluster_name="cluster1"

asm_type="${2:-managed}"
[[ "managed incluster " =~ $asm_type[[:space:]] ]] || { echo "ERROR only valid types are managed|incluster"; exit 3; }

asm_version="${3:-1.11}" # can only download minor versions 1.x, not revision 1.x.y: 1.11|1.12

region=us-east1
location_flag="--region $region"
asm_release_channel=rapid # regular|rapid for GKE Autopilot (cannot use stable)

KUBECONFIG="kubeconfig-${cluster_name}"

# ASM downloads
# Most current
#[ -f asmcli ] || curl https://storage.googleapis.com/csm-artifacts/asm/asmcli > asmcli
# latest <major>.<minor> version
# curl -LO https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.11
#
# ISTIO downloads
# exact <major>.<minor>.<revision>, listed here https://cloud.google.com/service-mesh/docs/release-notes
# curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.12.0-asm.4-linux-amd64.tar.gz
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
projectId=$(gcloud config get-value project)
projectName=$(gcloud projects list --filter=id=$projectId --format="value(name)")
[ -n "$projectName" ] || { echo "ERROR could not find project named based on id $projectId, try 'gcloud projects list'"; exit 4; }
echo "project id: $projectId"
echo "project name: $projectName"

# make sure GKE cluster meets requirements of 1.21.3+ for GKE Autopilot
cluster_min_allowed_version="v1.21.3"
if [ $cluster_type = "autopilot" ]; then
  worker_node_version=$(kubectl get nodes -o=jsonpath="{.items[].status.nodeInfo.kubeletVersion}")
  if [[ "$worker_node_version" < "$cluster_min_allowed_version" ]]; then
    echo "ERROR worker node version $worker_node_version is < $cluster_min_allowed_version"
    exit 5
  else
    echo "worker node $worker_node_version is >= $cluster_min_allowed_version"
  fi
fi

# workload identity must be enabled
workload_identity=$(gcloud container clusters describe $cluster_name --format="value(workloadIdentityConfig.workloadPool)" $location_flag)
[ -n "$workload_identity" ] || { echo "ERROR workload identity must not be enabled for this cluster, see 'gcloud container clusters describe'"; exit 5; }
echo "workload identity: $workload_identity"

# https://cloud.google.com/service-mesh/v1.7/docs/private-cluster-open-port
# port 15017 must be open for private GKE clusters so auto-injection works
firewall_rule_name=$(gcloud compute firewall-rules list --filter="name~gke-${cluster_name}-[0-9a-z]*-master" --format="value(name)")
echo "firewall rule that needs port 15017 added for ASM auto-injection"
gcloud compute firewall-rules update $firewall_rule_name --allow tcp:10250,tcp:443,tcp:15017,tcp:15014,tcp:8080

# validate valid KUBECONFIG
kubectl get nodes
[ $? -eq 0 ] || { echo "ERROR do you have a valid KUBECONFIG at $KUBECONFIG ?"; exit 3; }

kubectl get IstioOperator -n istio-system 1>/dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "IstioOperator is already installed, therefore no need to run asmcli install"
else
  mkdir -p output-$cluster_name
  if [ "managed" = $asm_type ]; then

    # https://cloud.google.com/service-mesh/docs/managed/service-mesh#gke_autopilot
    # asm must be in rapid|regular (not stable)
    set -x
    ./asmcli install \
        --project_id $projectId \
        --cluster_name $cluster_name \
        --fleet_id $projectId \
        --cluster_location $region \
        --managed \
        --verbose \
        --output_dir output-$cluster_name \
        --use_managed_cni \
        --channel $asm_release_channel \
        --enable-all
    set +x

  elif [ "incluster" = $asm_type ]; then

    set -x
    ./asmcli install \
        --project_id $projectId \
        --cluster_name $cluster_name \
        --fleet_id $projectId \
        --cluster_location $region \
        --output_dir output-$cluster_name \
        --enable_all \
        --ca mesh_ca
      #  --custom_overlay ingress-operator.yaml got errors
      #  --fleet_id FLEET_PROJECT_ID \ will use the cluster project if not specified
    set +x

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

  # associate ns label with the actual revision
  output-$cluster_name/istioctl x revision tag set asm-managed-rapid --revision $asm_rev_label_from_istiod --overwrite
  output-$cluster_name/istioctl x revision list

  # show current ns labels
  # set ASM revision label for namespace
  if [ -z "$asm_rev_label_from_ns" ]; then
    kubectl label namespace default istio-injection- istio.io/rev=$asm_rev_label_from_istiod --overwrite
  fi
  kubectl get ns istio-system --show-labels


elif [ "managed" = $asm_type ]; then

  kubectl get controlplanerevision asm-managed-$asm_release_channel -n istio-system
  if [ $? -ne 0 ]; then
    echo "ERROR with a managed ASM control plane, we would expect a controlplanerevision object"
    exit 7
  else
    echo "ASM already installed into istio-system"
    kubectl get controlplanerevision asm-managed-$asm_release_channel -n istio-system
    echo ""
    reconciled_status=$(kubectl get controlplanerevision asm-managed-stable -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Reconciled')].status}")
    stalled_status=$(kubectl get controlplanerevision asm-managed-stable -n istio-system -o=jsonpath="{.status.conditions[?(.type=='Stalled')].status}")
    echo "ASM control plan reconciled status: $reconciled_status (You want True)"
    echo "ASM control plan stalled status: $stalled_status (You want False)"
  fi
  
  # https://cloud.google.com/service-mesh/docs/managed/service-mesh#managed-data-plane
  # skipping the google-managed data plane which would recycle pods when ASM upgrade is done
  # kubectl annotate --overwrite namespace NAMESPACE mesh.cloud.google.com/proxy='{"managed":"true"}'
  # if kubectl get dataplanecontrols -o custom-columns=REV:.spec.revision,STATUS:.status.state | grep rapid | grep -v none > /dev/null; then echo "Managed Data Plane is ready."; else echo "Managed Data Plane is NOT ready."; fi
  
  # set revision label for namespace
  kubectl label namespace default istio-injection- istio.io/rev=asm-managed-$asm_release_channel --overwrite

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

