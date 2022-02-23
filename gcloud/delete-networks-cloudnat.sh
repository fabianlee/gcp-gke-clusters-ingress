#!/bin/bash
#
# Deletes network and NAT Cloud router
#

project_id="$1"
network_name="$2"
region="$3"

if [[ -z "$project_id" || -z "$network_name" || -z "$region" ]]; then
  echo "Usage: projectId networkName region"
  exit 3
fi


location_flag="--region $region"

gcloud config set project $project_id

set -x

# TODO these need to be deleted before deleting networks, k8s clusters leave them orphaned
gcloud compute network-endpoint-groups list --regions=$region
#gcloud compute network-endpoint-groups delete <name> --region=$region

echo "delete NAT Cloud"
gcloud compute routers nats delete ${network_name}-nat-gateway1 --router=${network_name}-router1 $location_flag --quiet
gcloud compute routers delete ${network_name}-router1 $location_flag --quiet

echo "delete subnets"
for subnet in pub-10-0-90-0 pub-10-0-91-0 prv-10-0-100-0 prv-10-0-101-0; do
  gcloud compute networks subnets delete $subnet --project $project_id --region=$region --quiet
done

echo "delete firewall rules"
for fwrule in $(gcloud compute firewall-rules list --project=$project_id --filter="network~$network_name" --format="value(name)"); do
  gcloud compute firewall-rules delete $fwrule --project=$project_id --quiet
done

echo "finally delete network"
gcloud compute networks delete $network_name --quiet

