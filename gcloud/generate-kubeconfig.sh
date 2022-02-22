#!/bin/bash
#
# Gets kubeconfig for cluster
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
cluster_name="$2"
is_regional_cluster="$3"
region="$4"
if [[ -z "$project_id" || -z "$cluster_name" || -z "$is_regional_cluster" || -z "$region" ]]; then
  echo "Usage: projectid clustername isRegionalCluster=0|1 region"
  exit 1
fi

#echo "is_regional_cluster is $is_regional_cluster"
if [ $is_regional_cluster -eq 1 ]; then
  location_flag="--region $region"
else
  location_flag="--zone $region-b" # use '-b' zone of region
fi


gcloud container clusters describe $cluster_name $location_flag 1>/dev/null 2>&1
[ $? -eq 0 ] || { echo "No cluster created named $cluster_name"; exit 0; }

if [ -f ../kubeconfig-$cluster_name ]; then
  echo "SKIP already generated kubeconfig for $cluster_name"
  exit 0
fi

set -x
KUBECONFIG=../kubeconfig-$cluster_name gcloud container clusters get-credentials $cluster_name $location_flag
retVal=$?
set +x
if [ $retVal -eq 0 ]; then
  echo "OK KUBECONFIG kubeconfig-$cluster_name"
else
  echo "ERROR writing KUBECONFIG for $cluster_name"
fi
