#!/bin/bash
#
# Creates GKE cluster and registers with Anthos hub
#
# Usage: clusterType=autopilot|standard exposedAs=public|private
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

cluster_type="$1"
exposed_as="$2"
cluster_name="$3"
project_id="$4"
network_name="$5"
subnet_name="$6"
master_cidr="$7"
additional_authorized_cidr="$8"
region="$9"
is_regional_cluster="${10:-0}" # 1=is regional multi-zonal
if [[ -z "$cluster_type" || -z "$exposed_as" || -z "$cluster_name" || -z "$project_id" || -z "$network_name" || -z "$subnet_name" || -z "$master_cidr" || -z "$region" ]]; then
  echo "Usage: clusterType=standard|autopilot exposedAs=public|private clusterName projectId networkName subnetName masterCIDR=a.b.c.d/28 additional_authorized_cidr=a.b.c.d/x regionprojectid networkName region isRegionalCluster=0|1"
  exit 1
fi

[[ "autopilot standard " =~ $cluster_type[[:space:]] ]] || { echo "ERROR only valid cluster types are standard|autopilot"; exit 3; }

# whether cluster is public or private
# https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters
# private means nodes have only internal IP, which means isolation from internet without CloudNAT
[[ "public private " =~ $exposed_as[[:space:]] ]] || { echo "ERROR only valid exposed types are public|private"; exit 3; }


# https://cloud.google.com/compute/docs/general-purpose-machines
echo "is_regional_cluster is $is_regional_cluster"
if [ $is_regional_cluster -eq 1 ]; then
  location_flag="--region $region"
  machine_type="e2-standard-2" # 2vcpu,8Gb
else
  location_flag="--zone $region-b" # use '-b' zone of region
  machine_type="e2-standard-4" # 4vcpu,16Gb, e2-standard-8=8vpu,32Gb
fi

if [ $cluster_type = "autopilot" ]; then
  echo "Autopilot means it MUST use regional cluster"
  location_flag="--region $region"
fi

num_nodes=1 # means 1 in each zone (3 total) if regional cluster type
image_type="UBUNTU_CONTAINERD" # UBUNTU | COS_CONTAINERD

cluster_release_channel="regular" # regular|rapid is mandatory if using Google managed ASM (cannot be 'stable')

# must be 1.21.3+ for managed ASM
# gcloud container get-server-config --region=us-east1 (lists GKE versions and OS types)
cluster_version="1.21.5-gke.1802" # 1.21.6-gke.1500 is next version
cluster_scopes="gke-default,cloud-source-repos-ro"
KUBECONFIG="../kubeconfig-${cluster_name}"

if [ $cluster_type = "standard" ]; then
  cluster_scopes="https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append"
fi

# prefix for selfLink values coming back from gcloud
googleapi="https://www.googleapis.com/compute/v1/"

# check for gcloud login context
gcloud projects list > /dev/null 2>&1
[ $? -eq 0 ] || gcloud auth login --no-launch-browser
gcloud auth list

# check gcloud version
# on apt, can be upgraded with 'sudo apt install --only-upgrade google-cloud-sdk -y'
gcloud --version | grep 'Google Cloud SDK'

# gcp project id should already be set before calling script
projectId=$(gcloud config get-value project)
[ -n "$projectId" ] || { echo "ERROR need to set project 'gcloud config set project' OR specify as param"; exit 4; }
echo "project id: $projectId"
gcloud config set project $projectId

# enable apis for fleet workload identity
gcloud services enable --project=$projectId \
   container.googleapis.com \
   gkeconnect.googleapis.com \
   gkehub.googleapis.com \
   cloudresourcemanager.googleapis.com \
   iam.googleapis.com \
   anthos.googleapis.com

# create autopilot cluster
cluster_count=$(gcloud container clusters list --filter=name~$cluster_name $location_flag | wc -l)
if [ $cluster_count -eq 0 ]; then

  # get rid of any old kubeconfig
  rm -f $KUBECONFIG

  if [ $cluster_type = "autopilot" ]; then

    extra_flags=""
    if [ "$exposed_as" = "private" ]; then 
      extra_flags="--enable-master-authorized-networks --master-authorized-networks=$additional_authorized_cidr --enable-private-nodes --enable-private-endpoint"
    fi
 
    # Autopilot clusters MUST be regional 
    set -ex
    gcloud container --project $projectId clusters create-auto $cluster_name $location_flag --release-channel "$cluster_release_channel" --cluster-version="$cluster_version" --network "$network_name" --subnetwork "$subnet_name" --cluster-secondary-range-name=pods --services-secondary-range-name=services --scopes="$cluster_scopes" --master-ipv4-cidr $master_cidr $extra_flags

    #gcloud container clusters update $cluster_name --project $projectId --disable-default-snat
    set +ex

  elif [ $cluster_type = "standard" ]; then

   
    extra_flags=""
    if [ "$exposed_as" = "private" ]; then 
      extra_flags="--disable-default-snat --enable-ip-alias --enable-master-global-access --enable-intra-node-visibility --enable-private-endpoint --enable-master-authorized-networks --master-authorized-networks=$additional_authorized_cidr"
    else
      extra_flags="--no-enable-master-authorized-networks"
    fi

    set -ex
    # even with public, we choose private nodes so nodes have unreachable internal IP but have public kubeapi endpoint
    gcloud beta container --project $projectId clusters create $cluster_name $location_flag --num-nodes $num_nodes --cluster-version="$cluster_version" --release-channel "$cluster_release_channel" --machine-type "$machine_type" --image-type "$image_type" --metadata disable-legacy-endpoints=true --scopes "$cluster_scopes" --max-pods-per-node "110" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "$network_name" --subnetwork "$subnet_name" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-metadata=GKE_METADATA --workload-pool $projectId.svc.id.goog --cluster-secondary-range-name=pods --services-secondary-range-name=services --enable-private-nodes --master-ipv4-cidr $master_cidr $extra_flags
    set +ex
  fi

  # if master auth networks needed to be set post-creation
  # gcloud container clusters update cluster1 --region=us-east1 --enable-master-authorized-networks --master-authorized-networks=10.99.0.0/24,10.100.0.0/24

  # update to set maintenance window flags
  # TODO put back in
  #gcloud container clusters update $cluster_name $location_flag --maintenance-window-start "2022-01-28T10:00:00Z" --maintenance-window-end "2022-01-28T14:00:00Z" --maintenance-window-recurrence "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"

  # register cluster with Anthos hub, delete any old registration first
  gcloud container hub memberships delete $cluster_name --quiet
  gcloud container hub memberships list
  gcloud container hub memberships register $cluster_name --gke-cluster=$region/$cluster_name --enable-workload-identity

  # make sure HttpLoadBalacing add-on is enabled for cluster, only editable on standard clusters
  # https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress#gcloud
  gcloud container clusters describe $cluster_name $location_flag | yq ".addonsConfig"
  # TODO put back in
  #gcloud container clusters update $cluster_name --update-addons=HttpLoadBalancing=ENABLED $location_flag

else
  echo "cluster $cluster_name already created"
fi


# https://cloud.google.com/anthos/multicluster-management/connect/prerequisites#enable_wi
# is fleet workload identity enabled?
workload_identity=$(gcloud container clusters describe $cluster_name --format="value(workloadIdentityConfig.workloadPool)" $location_flag)
echo "fleet workload identity: $workload_identity"


# create topic for cluster events (upgrade,security)
#https://cloud.google.com/pubsub/docs/admin#creating_a_topic
if [[ $(gcloud pubsub topics list | grep "/${cluster_name}$" | wc -l) -gt 0 ]]; then
  echo "topic $cluster_name already exists"
else
  echo "need to create topic $cluster_name"
  gcloud pubsub topics create $cluster_name
fi

# https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-notifications#enable-notifications-existing
set -x
gcloud container clusters update $cluster_name $location_flag \
    --notification-config=pubsub=ENABLED,pubsub-topic=projects/$projectId/topics/$cluster_name

# show IP of worker nodes
timeout 10 kubectl get nodes -o wide
if [ $? -ne 0 ]; then
  echo "kubectl failed. If this is a private GKE cluster with '--enable-private-endpoint' that makes sense because it would mean you cannot manage remotely and need to ssh into a jumpbox instead"
fi
