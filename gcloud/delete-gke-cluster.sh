#!/bin/bash

project_id="${1}"

cluster_type="${2:-autopilot}"
[[ "autopilot standard " =~ $cluster_type[[:space:]] ]] || { echo "ERROR only valid types are standard|autopilot"; exit 3; }

if [[ -z "$project_id" || -z "$cluster_type" ]]; then
  echo "Usage: projectId clusterType=autopilot|standard"
  exit 3
fi

[ $cluster_type = "autopilot" ] && cluster_name="autopilot-cluster1" || cluster_name="cluster1"

region="us-east1"
location_flag="--region $region"


set -x

# register cluster with Anthos hub
gcloud container hub memberships list
gcloud container hub memberships delete $cluster_name --quiet

# delete pub/sub topic for cluster events
gcloud pubsub topics delete $cluster_name --project=$project_id --quiet

gcloud container clusters delete $cluster_name $location_flag --project=$project_id --quiet


