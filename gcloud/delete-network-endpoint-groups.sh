#!/bin/bash
#
# Deletes network endpoint groups orphaned by k8s clusters
#

project_id="$1"
network_name="$2"
region="$3"

if [[ -z "$project_id" || -z "$network_name" || -z "$region" ]]; then
  echo "Usage: projectId networkName region"
  exit 3
fi


location_flag="--region $region"

set -x

# TODO these need to be deleted before deleting networks, k8s clusters leave them orphaned
gcloud compute network-endpoint-groups list --regions=$region
#gcloud compute network-endpoint-groups delete <name> --region=$region

