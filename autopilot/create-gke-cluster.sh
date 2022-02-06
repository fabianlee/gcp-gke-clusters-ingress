#!/bin/bash
#
# Creates GKE cluster and registers with Anthos hub
#
# Usage: clusterType=autopilot|standard
#

# by default creates AutoPilot GKE cluster
cluster_type="${1:-autopilot}"
[[ "autopilot standard " =~ $cluster_type[[:space:]] ]] || { echo "ERROR only valid types are standard|autopilot"; exit 3; }

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
   iam.googleapis.com

# use 'default' network
default_network_count=$(gcloud compute networks list --filter=name~default | wc -l)
[ $default_network_count -gt 0 ] || { echo "ERROR did not find 'default' network"; exit 5; }

# get qualified link to network
default_network_qual=$(gcloud compute networks describe default --format="value(selfLink)" | sed  "s#$googleapi##")
[ -n "$default_network_qual" ] || { echo "ERROR could not describe default network"; exit 5; }
echo "default network: $default_network_qual"

# get qualified link to subnetwork
default_subnetwork_qual=$(gcloud compute networks subnets list --filter="region:($region)" --format="value(selfLink)" | head -n1 | sed  "s#$googleapi##")
[ -n "$default_subnetwork_qual" ] || { echo "ERROR could not list default subnetwork"; exit 5; }
echo "default subnetwork: $default_subnetwork_qual"


# create autopilot cluster
cluster_count=$(gcloud container clusters list --filter=name~$cluster_name $location_flag | wc -l)
if [ $cluster_count -eq 0 ]; then

  # get rid of old kubeconfig
  rm -f kubeconfig-$cluster_name

  if [ $cluster_type = "autopilot" ]; then
    set -ex
    gcloud container --project $projectId clusters create-auto $cluster_name $location_flag --release-channel "$cluster_release_channel" --cluster-version="$cluster_version" --network "$default_network_qual" --subnetwork "$default_subnetwork_qual" --cluster-ipv4-cidr "/17" --services-ipv4-cidr "/22" --scopes="$cluster_scopes"
    set +ex
  elif [ $cluster_type = "standard" ]; then

    private_flags="--create-subnetwork name=private-subnet,range=10.0.0.0/16 --disable-default-snat --enable-ip-alias --enable-private-nodes --cluster-ipv4-cidr 10.1.0.0/17 --services-ipv4-cidr 10.2.0.0/19 --enable-master-global-access --enable-intra-node-visibility  --master-ipv4-cidr 10.99.0.0/28"

    # for zonal with 1 node, use e2-standard-2 (2vcpu,8Gb)
    set -ex
    gcloud beta container --project $projectId clusters create $cluster_name $location_flag --num-nodes 1 --cluster-version="$cluster_version" --release-channel "$cluster_release_channel" --machine-type "e2-standard-2" --image-type "UBUNTU" --metadata disable-legacy-endpoints=true --scopes "$cluster_scopes" --max-pods-per-node "110" --logging=SYSTEM,WORKLOAD --monitoring=SYSTEM --enable-ip-alias --network "$default_network_qual" --subnetwork "$default_subntwork_qual" --no-enable-intra-node-visibility --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing,GcePersistentDiskCsiDriver --enable-autorepair --max-surge-upgrade 1 --max-unavailable-upgrade 0 --workload-metadata=GKE_METADATA --workload-pool $projectId.svc.id.goog $private_flags
    set +ex
  fi

  # update to set maintenance window flags
  gcloud container clusters update $cluster_name $location_flag --maintenance-window-start "2022-01-28T10:00:00Z" --maintenance-window-end "2022-01-28T14:00:00Z" --maintenance-window-recurrence "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU"

  # register cluster with Anthos hub
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
gcloud container clusters update $cluster_name $location_flag \
    --notification-config=pubsub=ENABLED,pubsub-topic=projects/$projectId/topics/$cluster_name

# make sure HttpLoadBalacing add-on is enabled for cluster
# https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress#gcloud
gcloud container clusters update $cluster_name --update-addons=HttpLoadBalancing=ENABLED

# for private GKE clusters, must create Cloud NAT so that worker nodes can reach public images
# https://cloud.google.com/sdk/gcloud/reference/compute/routers/nats/create?hl=nb
gcloud compute routers create router1 --network=$default_network_qual --region=$region
gcloud compute routers nats create nat-gateway1 --router=router1 --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --region=$region 

