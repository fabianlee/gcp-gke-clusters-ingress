#!/bin/bash
#
# Creates VM instance
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

vm_type="$1"
project_id="$2"
network_name="$3"
subnet_name="$4"
region="$5"
if [[ -z "$vm_type" || -z "$project_id" || -z "$network_name" || -z "$subnet_name" || -z "$region" ]]; then
  echo "Usage: vmType=public|private projectid networkName subnetName region"
  exit 1
fi


gcloud config set project $project_id

# gcloud compute images list
image_flags="--image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud"

set -x
gcloud compute instances create vm-$vm_type $image_flags \
--zone=$region-b \
--machine-type=n1-standard-1 \
--subnet=$subnet_name \
--scopes=cloud-platform

# setting scope post-creation requires stop of instance first
# gcloud beta compute instances set-scopes vm-$vm_type --scopes=cloud-platform --zone=$region-b


# ssh into VM
gcloud compute ssh vm-$vm_type --zone=$region-b

# vm with 'cloud-platform' scope, already have auth based on metadata
# gcloud config set project mygke-proj1
# gcloud container clusters list
# export KUBECONFIG=kubeconfig-cluster1
# gcloud container clusters get-credentials cluster1 --region=us-east1 (--internal-ip)

# install
# https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl
# sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
# echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
# sudo apt-get update && sudo apt-get install -y kubectl
# 
# kubectl get nodes -o wide


