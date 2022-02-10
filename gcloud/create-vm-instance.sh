#!/bin/bash
#
# Creates VM instance
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

vm_type="$1"
vm_name="$2"
project_id="$3"
network_name="$4"
subnet_name="$5"
region="$6"
if [[ -z "$vm_type" || -z "$vm_name" || -z "$project_id" || -z "$network_name" || -z "$subnet_name" || -z "$region" ]]; then
  echo "Usage: vmType=public|private vmName projectid networkName subnetName region"
  exit 1
fi


gcloud config set project $project_id

# gcloud compute images list
image_flags="--image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud"
# 'pubjumpbox' is network tag for firewall rule that allows ssh
[ "public" = "$vm_type" ] && extra_flags="--tags=pubjumpbox" || extra_flags="--no-address"

# os login explanation: https://medium.com/@0d6e/options-for-managing-ssh-access-on-google-compute-engine-e629b3203664

set -x
gcloud compute instances create $vm_name $image_flags \
--zone=$region-b \
--machine-type=e2-small \
--subnet=$subnet_name \
--scopes=cloud-platform \
--metadata enable-oslogin=TRUE \
$extra_flags \
--async

cat <<EOL

You can login to VM instances with public IP:
ssh ubuntu@<privateIP> -i gcp-ssh


You can login to private VM instance via public bastion by adding the following to ~/.ssh/config

Host <bastionIP>
  ForwardAgent Yes
  IdentityFile $(cd ..; pwd)/gcp-ssh

Then invoking:
ssh -J ubuntu@<bastionIP> ubuntu@<privateIP> -i gcp-ssh

EOL

# setting scope post-creation requires stop of instance first
# gcloud beta compute instances set-scopes vm-$vm_type --scopes=cloud-platform --zone=$region-b


# ssh into VM
#gcloud compute ssh $vm_name --zone=$region-b

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


