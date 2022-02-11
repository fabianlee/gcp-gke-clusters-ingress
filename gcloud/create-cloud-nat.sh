#!/bin/bash
#
# Creates Cloud NAT which allows public egress for private IP
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
network_name="$2"
region="$3"
if [[ -z "$project_id" || -z "$network_name" || -z "$region" ]]; then
  echo "Usage: projectid networkName region"
  exit 1
fi

gcloud config set project $project_id

# Cloud NAT for egress in private subnet
# https://cloud.google.com/sdk/gcloud/reference/compute/routers/nats/create?hl=nb
set -x
gcloud compute routers create ${network_name}-router1 --network=$network_name --region=$region

gcloud compute routers nats create ${network_name}-nat-gateway1 --router=${network_name}-router1 --auto-allocate-nat-external-ips --nat-all-subnet-ip-ranges --region=$region 
