#!/bin/bash

project_id="$1"
cluster_name="$2"
region="$3"
is_regional_cluster="$4"
if [[ -z "$project_id" || -z "$cluster_name" || -z "$region" || -z "$is_regional_cluster" ]]; then
  echo "Usage: projectId clusterName region is_regional_cluster=0|1"
  exit 3
fi


if [ $is_regional_cluster -eq 1 ]; then
  location_flag="--region $region"
else
  location_flag="--zone $region-b"
fi


set -x

# register cluster with Anthos hub
gcloud container hub memberships list
gcloud container hub memberships delete $cluster_name --quiet

# delete cluster
gcloud container clusters delete $cluster_name $location_flag --project=$project_id --quiet

# delete pub/sub topic for cluster events
gcloud pubsub topics delete $cluster_name --project=$project_id --quiet

# get rid of local file
rm -f kubeconfig-$cluster_name
