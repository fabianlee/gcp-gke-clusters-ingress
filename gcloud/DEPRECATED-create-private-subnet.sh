#!/bin/bash
#
# Creates private subnetwork
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
network_name="$2"
subnet_name="$3"
cidr="$4"
secondary_cidr1="$5"
secondary_cidr2="$6"
region="$7"
if [[ -z "$project_id" || -z "$network_name" || -z "$subnet_name" || -z "$cidr" || -z "$secondary_cidr1" || -z "$secondary_cidr2" || -z "$region" ]]; then
  echo "Usage: projectid subnetName CIDR secondaryCIDR1 secondaryCIDR2 region"
  exit 1
fi


gcloud config set project $project_id


gcloud compute networks subnets create $subnet_name --project $project_id --network $network_name --range="$cidr" --secondary-range pods=$secondary_cidr1 --secondary-range services=$secondary_cidr2 --region=$region


# Cloud NAT for egress in private subnet
# https://cloud.google.com/sdk/gcloud/reference/compute/routers/nats/create?hl=nb
gcloud compute routers create ${network_name}-router1 --network=$network_name --region=$region
gcloud compute routers nats create ${network_name}-nat-gateway1 --router=${network_name}-router1 --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --region=$region 

exit 0

