#!/bin/bash
#
# SSH into vm using IP addresses known by terraform
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

vm_name="$1"
if [[ -z "$vm_name" ]]; then
  echo "Usage: vmName"
  exit 1
fi

ssh_key="$(cd ..;pwd)/gcp-ssh"

# public jumpboxes (also serve as bastions for private networks)
cd vms
pub1=$(terraform output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value[\"pub-10-0-90-0\"]" -r)
pub2=$(terraform output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value[\"pub-10-0-91-0\"]" -r)

# private jumpboxes (must go through public bastion above)
priv1=$(terraform output -json --state=../envs/vms.tfstate | jq ".module_internal_ip.value[\"prv-10-0-100-0\"]" -r)
priv2=$(terraform output -json --state=../envs/vms.tfstate | jq ".module_internal_ip.value[\"prv-10-0-101-0\"]" -r)
cd ..

echo "pub1/pub2 = $pub1/$pub2"
echo "prv1/prv2 = $priv1/$priv2"

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
    set -x
    ssh -J ubuntu@${pub1} ubuntu@$priv1 -i $ssh_key
    set +x
  ;;

  vm-prv-10-0-101-0)
    set -x
    ssh -J ubuntu@${pub2} ubuntu@$priv2 -i $ssh_key
    set +x
  ;;

  *)
    echo "ERROR did not recognize that vmName $vm_name"
  ;;

esac


