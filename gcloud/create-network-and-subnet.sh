#!/bin/bash
#
# Creates subnetwork in 'default' network
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
network_name="$2"
subnet_name="$3"
cidr="$4"
fw_internal_cidr="$5"
region="$6"
if [[ -z "$project_id" || -z "$network_name" || -z "$subnet_name" || -z "$cidr" || -z "$fw_internal_cidr" || -z "$region" ]]; then
  echo "Usage: projectid subnetName CIDR firewallInternalCIDR region"
  exit 1
fi


gcloud config set project $project_id

set -x
gcloud compute networks create $network_name --subnet-mode=custom

gcloud compute networks subnets create $subnet_name --project $project_id --network $network_name --range="$cidr" --region=$region

echo "minimal set of firwall rules for allowing all internal and public ssh"
# OR --rules=all
gcloud compute firewall-rules create ${network_name}-allow-internal --project=$project_id --direction=INGRESS --priority=1000 --network=mynetwork --action=ALLOW --rules=tcp:0-65535,udp:0-65535 --source-ranges=$fw_internal_cidr

gcloud compute firewall-rules create ${network_name}-ext-ssh-allow --project=$project_id --network $network_name --action=ALLOW --rules=icmp,tcp:22 --source-ranges=0.0.0.0/0 --direction=INGRESS

