#!/bin/bash
#
# SSH into vm
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
vm_name="$2"
region="$3"
if [[ -z "$project_id" || -z "$vm_name" || -z "$region" ]]; then
  echo "Usage: projectId vmName region"
  exit 1
fi

set -x

gcloud config set project $project_id

ssh_key="$(cd ..;pwd)/gcp-ssh"

# public jumpboxes (also serve as bastions for private networks)
pub1=$(gcloud compute instances describe vm-pub-10-0-90-0 --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --zone=$region-b)
pub2=$(gcloud compute instances describe vm-pub-10-0-91-0 --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --zone=$region-b)

case $vm_name in

  vm-pub-10-0-90-0)
    set -x
    ssh ubuntu@${pub1} -i $ssh_key
    set +x
  ;;

  vm-pub-10-0-91-0)
    set -x
    ssh ubuntu@${pub2} -i $ssh_key
    set +x
  ;;

  vm-prv-10-0-100-0)
    priv1=$(gcloud compute instances describe vm-prv-10-0-100-0 --format='get(networkInterfaces.networkIP)' --zone=$region-b)
    set -x
    ssh -J ubuntu@${pub1} ubuntu@$priv1 -i $ssh_key
    set +x
  ;;

  vm-prv-10-0-101-0)
    priv2=$(gcloud compute instances describe vm-prv-10-0-101-0 --format='get(networkInterfaces.networkIP)' --zone=$region-b)
    set -x
    ssh -J ubuntu@${pub2} ubuntu@$priv2 -i $ssh_key
    set +x
  ;;

  *)
    echo "ERROR did not recognize that vmName $vm_name"
  ;;

esac
  



