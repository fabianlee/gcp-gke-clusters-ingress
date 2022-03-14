#!/bin/bash
#
# gets all the current GKE versions, lets you pick from the REGULAR channel options
#

region=us-east1
source tf/envs/all.tfvars
echo "vpc_network_name is $vpc_network_name"

yqbin=$(which yq)
[ -n "$yqbin" ] || { echo "ERROR you need yq installed to run this script"; exit 3; }

echo "About to fetch the cluster versions available in us-east1, this can take a couple of minutes..."
versions_file=/tmp/gke-${region}-versions.yaml
[ -f "$versions_file" ] || gcloud container get-server-config --region=$region > $versions_file

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
sed -i "s/cluster_version_prefix =.*/cluster_version_prefix = \"$selected_version\"/" tf/envs/all.tfvars

echo "======== RESULTS ============"
grep ^cluster_version global.properties
grep ^cluster_version group_vars/all
grep ^cluster_version_prefix tf/envs/all.tfvars

