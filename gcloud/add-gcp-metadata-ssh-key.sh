#!/bin/bash
#
# Adds public side of ssh key to GCP metadata
# which allows login to VM
#
# this could be done with terraform google_compute_project_metadata, 
# but gcloud logins change the ssh keys and would cause lots of unexpected diffs
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_project_metadata
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
if [[ -z "$project_id" ]]; then
  echo "Usage: projectid"
  exit 1
fi

current_user=$(gcloud config list --format="value(core.account)")
echo "current_user is $current_user"
login_user=ubuntu

# using elliptical curve key which has smaller key
[ -f ../gcp-ssh ] || ssh-keygen -t ed25519 -f ../gcp-ssh -C $login_user -N "" -q
# if you want RSA instead
#[ -f ../gcp-ssh ] || ssh-keygen -t rsa -b 4096 -f ../gcp-ssh -C $login_user -N "" -q

# https://cloud.google.com/compute/docs/metadata/setting-custom-metadata
# GCP wants public key file prefixed with username, so we must synthesize that
echo "Going to add project-level ssh metdata for ssh instances"
prefixed_username_pub="$login_user:$(cat ../gcp-ssh.pub)"
set -x
gcloud compute project-info add-metadata --project=$project_id --metadata-from-file ssh-keys=<(echo $prefixed_username_pub)

# for vm targeted ssh metadata
# gcloud compute instances <instanceName> add-metadata-from-file

echo "You can login to GCP vm instances using the private key:"
echo "ssh ubuntu@<PUBLICIP> -i ./gcp-ssh"
