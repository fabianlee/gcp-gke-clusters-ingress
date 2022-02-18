#!/bin/bash
#
# Creates GKE cluster and registers with Anthos hub
#
# Usage: clusterType=autopilot|standard exposedAs=public|private
#

# by default creates AutoPilot GKE cluster
cluster_type="${1:-autopilot}"
[[ "autopilot standard " =~ $cluster_type[[:space:]] ]] || { echo "ERROR only valid cluster types are standard|autopilot"; exit 3; }

# whether cluster is public or private
# https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters
# private means nodes have only internal IP, which means isolation from internet without CloudNAT
exposed_as="${2:-public}"
[[ "public private " =~ $exposed_as[[:space:]] ]] || { echo "ERROR only valid exposed types are public|private"; exit 3; }

# determine name of cluster
[ $cluster_type = "autopilot" ] && cluster_name="autopilot-cluster1" || cluster_name="cluster1"

region=us-east1
location_flag="--region $region"
cluster_release_channel="regular" # regular|rapid are mandatory for managed ASM (cannot be 'stable')

# must be 1.21.3+ for managed ASM, gcloud container get-server-config --region=us-east1
cluster_version="1.21.5-gke.1802" # 1.21.6-gke.1500 is next version
cluster_scopes="gke-default,cloud-source-repos-ro"
KUBECONFIG="kubeconfig-${cluster_name}"

if [ $cluster_type = "standard" ]; then
  cluster_scopes="https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/trace.append"
fi

# prefix for selfLink values coming back from gcloud
googleapi="https://www.googleapis.com/compute/v1/"

network_name=mynetwork
subnetwork_name=mysubnet-private


# check for gcloud login context
gcloud projects list > /dev/null 2>&1
[ $? -eq 0 ] || gcloud auth login --no-browser
gcloud auth list

# check gcloud version
# on apt, can be upgraded with 'sudo apt install --only-upgrade google-cloud-sdk -y'
gcloud --version | grep 'Google Cloud SDK'

# gcp project id should already be set before calling script
projectId=$(gcloud config get-value project)
[ -n "$projectId" ] || { echo "ERROR need to set project 'gcloud config set project' OR specify as param"; exit 4; }

# get project name
projectName=$(gcloud projects list --filter=id=$projectId --format="value(name)")
[ -n "$projectName" ] || { echo "ERROR could not find project named based on id $projectId, try 'gcloud projects list'"; exit 4; }
echo "project id: $projectId"
echo "project name: $projectName"
gcloud config set project $projectId

# enable apis for fleet workload identity
gcloud services enable --project=$projectId \
   container.googleapis.com \
   gkeconnect.googleapis.com \
   gkehub.googleapis.com \
   cloudresourcemanager.googleapis.com \
   iam.googleapis.com \
   anthos.googleapis.com

network_count=$(gcloud compute networks list --filter="name=$network_name" | wc -l)
[ $network_count -gt 0 ] || { echo "ERROR did not find '$network_name' network"; exit 5; }

# get qualified link to network
network_qual=$(gcloud compute networks describe $network_name --format="value(selfLink)" | sed  "s#$googleapi##")
[ -n "$network_qual" ] || { echo "ERROR could not describe $network_name network"; exit 5; }
echo "network: $network_qual"

# get qualified link to subnetwork
subnetwork_qual=$(gcloud compute networks subnets list --filter="network~$network_name AND name~$subnetwork_name" --format="value(selfLink)" | head -n1 | sed  "s#$googleapi##")
#[ -n "$subnetwork_qual" ] || { echo "ERROR could not list subnetwork"; exit 5; }
echo "subnetwork: $subnetwork_qual"


# create autopilot cluster
cluster_count=$(gcloud container clusters list --filter=name~$cluster_name $location_flag | wc -l)
if [ $cluster_count -eq 0 ]; then

  # get rid of old kubeconfig
  rm -f kubeconfig-$cluster_name

  if [ $cluster_type = "autopilot" ]; then

    private_flags=""
    if [ "$exposed_as" = "private" ]; then 
      private_flags="--enable-master-authorized-networks --enable-private-nodes --enable-private-endpoint"
    fi
   
    set -ex
    gcloud container --project $projectId clusters create-auto $cluster_name $location_flag --release-channel "$cluster_release_channel" --cluster-version="$cluster_version" --network "$network_qual" --subnetwork "$subnetwork_qual" --cluster-secondary-range-name=pods --services-secondary-range-name=services --master-authorized-networks=10.99.0.0/24,10.100.0.0/24 --scopes="$cluster_scopes" $private_flags
    set +ex
  elif [ $cluster_type = "standard" ]; then

    
    # if private GKE cluster, you can have gcloud create subnets for you OR you can precreate and reference
    # --create-subnetwork name=$subnetwork_name,range=10.99.0.0/24 OR --subnetwork=$subnetwork_name
    # --cluster-ipv4-cidr 10.0.0.0/17 OR --cluster-secondary-range-name=pods
    # --services-ipv4-cidr 10.0.128.0/17 OR --services-secondary-range-name=services
    private_flags=""
    if [ "$exposed_as" = "private" ]; then 
      private_flags="--disable-default-snat --enable-ip-alias --enable-private-nodes --enable-master-global-access --enable-intra-node-visibility --enable-private-endpoint --enable-master-authorized-networks --master-authorized-networks=10.99.0.0/24,10.100.0.0/24"
    else
      private_flags="--no-enable-master-authorized-networks"
    fi

    # for zonal with 1 node, use e2-standard-2 (2vcpu,8Gb)
    set -ex
    gcloud beta container --project $projectId clusters create $cluster_name $location_flag --num-nodes 1 --cluster-version="$cluster_version" --release-channel "$cluster_release_channel" --machine-type "e2-standard-2" --image-type "UBUNTU" --metadata disable-legacy-endpoints=true --scopes "$cluster_scopes" --max-pods-per-node "110" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "$network_qual" --subnetwork "$subnetwork_qual" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-metadata=GKE_METADATA --workload-pool $projectId.svc.id.goog --cluster-secondary-range-name=pods --services-secondary-range-name=services --master-ipv4-cidr 10.1.0.0/28 $private_flags
    set +ex
  fi

  # if master auth networks needed to be set post-creation
  # gcloud container clusters update cluster1 --region=us-east1 --enable-master-authorized-networks --master-authorized-networks=10.99.0.0/24,10.100.0.0/24

  # update to set maintenance window flags
  gcloud container clusters update $cluster_name $location_flag --maintenance-window-start "2022-01-28T10:00:00Z" --maintenance-window-end "2022-01-28T14:00:00Z" --maintenance-window-recurrence "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"

  # register cluster with Anthos hub, delete any old registration first
  gcloud container hub memberships delete $cluster_name --quiet
  gcloud container hub memberships list
  gcloud container hub memberships register $cluster_name --gke-cluster=$region/$cluster_name --enable-workload-identity

else
  echo "GKE Authpilot cluster $cluster_name already created"
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

# make sure HttpLoadBalacing add-on is enabled for cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress#gcloud
gcloud container clusters update $cluster_name --update-addons=HttpLoadBalancing=ENABLED $location_flag

# show IP of worker nodes
timeout 10 kubectl get nodes -o wide
if [ $? -ne 0 ]; then
  echo "kubectl failed. If this is a private GKE cluster with '--enable-private-endpoint' that makes sense because it would mean you cannot manage remotely"
fi
