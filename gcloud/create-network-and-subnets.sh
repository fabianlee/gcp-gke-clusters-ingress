#!/bin/bash
#
# Creates subnetwork in 'default' network
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
network_name="$2"
region="$3"
firewall_internal_allow_cidr="$4"
if [[ -z "$project_id" || -z "$network_name" || -z "$region" || -z "$firewall_internal_allow_cidr" ]]; then
  echo "Usage: projectid networkName region"
  exit 1
fi

function create_gke_subnet() {
  project_id="$1"
  network_name="$2"
  subnet_name="$3"
  cidr="$4"
  pods_cidr="$5"
  services_cidr="$6"
  region="$7"

  gcloud compute networks subnets create $subnet_name --project $project_id --network $network_name --range="$cidr" --region=$region --secondary-range pods=$pods_cidr --secondary-range services=$services_cidr

  # if wanting to update with secondary ranges after creation
  #gcloud compute networks subnets update $subnet_name --region=$region --add-secondary-ranges pods=$pods_cidr --add-secondary-ranges services=$services_cidr
 

}

gcloud config set project $project_id

echo "create VPC network"
set -x
gcloud compute networks create $network_name --subnet-mode=custom

# https://www.davidc.net/sites/default/subnets/subnets.html
# subdivided 10.126.0.0/15 into 4 spaces of /17
# subdivided 10.128.0.0/17 into 4 spaces of /19
# secondary ranges cannot collide with primary CIDR of subnet 10.0.90,91,100,101/24
# secondary ranges must be unique within VPC also
create_gke_subnet $project_id $network_name "pub-10-0-90-0"  10.0.90.0/24  10.126.0.0/17   10.128.0.0/19  $region 
create_gke_subnet $project_id $network_name "pub-10-0-91-0"  10.0.91.0/24  10.126.128.0/17 10.128.32.0/19 $region
create_gke_subnet $project_id $network_name "prv-10-0-100-0" 10.0.100.0/24 10.127.0.0/17   10.128.64.0/19 $region
create_gke_subnet $project_id $network_name "prv-10-0-101-0" 10.0.101.0/24 10.127.128.0/17 10.128.96.0/19 $region


echo "minimal firewall rule for allowing all internal traffic"
# OR --rules=all
gcloud compute firewall-rules create ${network_name}-allow-internal --project=$project_id --direction=INGRESS --priority=1000 --network=mynetwork --action=ALLOW --rules=tcp:0-65535,udp:0-65535 --source-ranges=$firewall_internal_allow_cidr

echo "allow ssh into vms with 'pubjumpbox' network tag"
gcloud compute firewall-rules create ${network_name}-ext-ssh-allow --project=$project_id --network $network_name --action=ALLOW --rules=icmp,tcp:22 --source-ranges=0.0.0.0/0 --direction=INGRESS --target-tags=pubjumpbox

