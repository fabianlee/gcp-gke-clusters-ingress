#!/bin/bash
#
# Deletes zonal network endpoint groups orphaned by k8s clusters
#

project_id="$1"
network_name="$2"
region="$3"
if [[ -z "$project_id" || -z "$network_name" || -z "$region" ]]; then
  echo "Usage: projectId networkName region"
  exit 3
fi


# these need to be deleted before deleting networks, k8s clusters leave them orphaned
# even standard gke clusters leaves one
gcloud compute network-endpoint-groups list --project=$project_id

# show all in project
for line in $(gcloud compute network-endpoint-groups list --project $project_id --format="csv(name,zone)" | tail -n+2); do
  neg_name=$(echo $line | cut -d, -f1)
  zone_full=$(echo $line | cut -d, -f2)
  set -x
  gcloud compute network-endpoint-groups delete $neg_name --project=$project_id --zone=$zone_full --quiet
  set +x
done

