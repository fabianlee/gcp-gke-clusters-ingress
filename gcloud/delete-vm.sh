#!/bin/bash
#
# Deletes VM instance
#

project_id="$1"
vm_name="$2"
region="$3"

if [[ -z "$project_id" || -z "$vm_name" || -z "$region" ]]; then
  echo "Usage: projectId vmName region"
  exit 3
fi

# created instances in zone 'b'
location_flag="--zone $region-b"

gcloud config set project $project_id

set -x
gcloud compute instances delete $vm_name $location_flag --quiet


