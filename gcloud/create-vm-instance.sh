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
cloud_scope="$7"
preemptible="$8"
if [[ -z "$vm_type" || -z "$vm_name" || -z "$project_id" || -z "$network_name" || -z "$subnet_name" || -z "$region" ]]; then
  echo "Usage: vmType=public|private vmName projectid networkName subnetName region [cloudScope=0|1] [preemtible=0|1]"
  exit 1
fi


gcloud config set project $project_id

# gcloud compute images list
image_flags="--image-family=ubuntu-2004-lts --image-project=ubuntu-os-cloud"

extra_flags=""
if [ "$cloud_scope" -eq 1 ]; then
  extra_flags="--scopes=cloud-platform"
fi
if [ "$preemptible" -eq 1 ]; then
  extra_flags="--preemptible"
fi
# 'pubjumpbox' is network tag for firewall rule that allows ssh
[ "public" = "$vm_type" ] && extra_flags="$extra_flags --tags=pubjumpbox" || extra_flags="$extra_flags --no-address"

# os login explanation: https://medium.com/@0d6e/options-for-managing-ssh-access-on-google-compute-engine-e629b3203664

set -x
gcloud compute instances create $vm_name $image_flags \
--zone=$region-b \
--machine-type=e2-small \
--subnet=$subnet_name \
--metadata enable-oslogin=TRUE \
$extra_flags \
--async

#cat <<EOL
#
#You can login to VM instances with public IP:
#ssh ubuntu@<privateIP> -i gcp-ssh
#
#
#You can login to private VM instance via public bastion by adding the following to ~/.ssh/config
#
#Host <bastionIP>
#  ForwardAgent Yes
#  IdentityFile $(cd ..; pwd)/gcp-ssh
#
#Then invoking:
#ssh -J ubuntu@<bastionIP> ubuntu@<privateIP> -i gcp-ssh
#
#EOL

# setting scope post-creation requires stop of instance first
# setting to 'cloud-platform' provides gcloud auth as engine acct
# gcloud beta compute instances set-scopes vm-$vm_type --scopes=cloud-platform --zone=$region-b

# ssh into VM
#gcloud compute ssh $vm_name --zone=$region-b

