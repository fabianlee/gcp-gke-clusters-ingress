#!/bin/bash
#
# gets all the current GKE versions, lets you pick from the REGULAR channel options
#

region=us-east1
source tf/envs/all.tfvars
echo "vpc_network_name is $vpc_network_name"

# check for gcloud login context
gcloud projects list > /dev/null 2>&1
[ $? -eq 0 ] || gcloud auth login --no-launch-browser
gcloud auth list

yqbin=$(which yq)
[ -n "$yqbin" ] || { echo "ERROR you need yq installed to run this script"; exit 3; }

# create file that looks like it was created 1 day ago
agedfile=$(mktemp)
touch -d "1 days ago" $agedfile

versions_file=/tmp/gke-${region}-versions.yaml
# file must exist and be of size greater than 0
if [[ ! -f "$versions_file" || $(stat -c%s $versions_file) -eq 0 || "$versions_file" -ot "$agedfile" ]]; then
  echo "About to fetch the cluster versions available in us-east1, this can take a couple of minutes..."
  gcloud container get-server-config --region=$region | tee $versions_file
  echo "DONE with fetch"
fi

default_version=$(cat $versions_file | yq ".channels[] | select (.channel==\"REGULAR\").defaultVersion")

echo ""
echo "Versions available in REGULAR channel:"
cat $versions_file | yq ".channels[] | select (.channel==\"REGULAR\").validVersions"

echo ""
read -p "Which GKE cluster version do you want (default=$default_version)? " selected_version
[ -n "$selected_version" ] || selected_version=$default_version

echo "You selected GKE version $selected_version"

# do replacements in files
sed -i "s/cluster_version=.*/cluster_version=$selected_version/" global.properties
sed -i "s/cluster_version:.*/cluster_version: \"$selected_version\"/" group_vars/all
sed -i "s/cluster_version_prefix=.*/cluster_version_prefix=\"$selected_version\"/" tf/envs/all.tfvars

echo "======== RESULTS ============"
grep ^cluster_version global.properties
grep ^cluster_version group_vars/all
grep ^cluster_version_prefix tf/envs/all.tfvars


default_type="COS_CONTAINERD"
echo ""
read -p "Which GKE node type do you want (default=$default_type)? " selected_type
[ -n "$selected_type" ] || selected_type=$default_type
sed -i "s/node_image_type=.*/node_image_type=\"$selected_type\"/" tf/envs/all.tfvars
echo "======== RESULTS ============"
grep ^node_image_type tf/envs/all.tfvars

