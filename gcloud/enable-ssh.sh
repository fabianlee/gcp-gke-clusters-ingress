#!/bin/bash
#
# Shows public IP for VMs, and bastion configs
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
region="$2"
if [[ -z "$project_id" || -z "$region" ]]; then
  echo "Usage: projectId region"
  exit 1
fi


gcloud config set project $project_id

export pub1=$(gcloud compute instances describe vm-pub-10-0-90-0 --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --zone=$region-b)
export pub2=$(gcloud compute instances describe vm-pub-10-0-91-0 --format='get(networkInterfaces[0].accessConfigs[0].natIP)' --zone=$region-b)

export priv1=$(gcloud compute instances describe vm-prv-10-0-100-0 --format='get(networkInterfaces.networkIP)' --zone=$region-b)
export priv2=$(gcloud compute instances describe vm-prv-10-0-101-0 --format='get(networkInterfaces.networkIP)' --zone=$region-b)


ssh_key="$(cd ..;pwd)/gcp-ssh"

# remove any saved ssh thumbprints from previous builds
ssh-keygen -f ~/.ssh/known_hosts -R $pub1 2>/dev/null
ssh-keygen -f ~/.ssh/known_hosts -R $pub2 2>/dev/null

# add public vms as bastion to ~/.ssh/config
touch ~/.ssh/config
for bastion in $pub1 $pub2; do
  if grep -qe "Host $bastion" ~/.ssh/config; then
    echo "bastion $bastion already in ~/.ssh/config"
  else

    echo "need to add bastion $bastion to ~/.ssh/config"
    cat << EOF >> ~/.ssh/config
Host $bastion
  ForwardAgent Yes
  IdentityFile $ssh_key
EOF

  fi
done

echo ""
echo "Writing ansible_inventory.ini configured for jumpbox and bastion usage"
cat ../ansible_inventory.ini.template | envsubst > ../ansible_inventory.ini


cat <<EOL

==============================
ssh into public vm-pub-10-0-90-0
  ssh ubuntu@${pub1} -i $ssh_key

ssh into public vm-pub-10-0-91-0
  ssh ubuntu@${pub2} -i $ssh_key

ssh into private vm-prv-10-0-100-0 using bastion
  ssh -J ubuntu@${pub1} ubuntu@$priv1 -i $ssh_key

ssh into private vm-prv-10-0-101-0 using bastion
  ssh -J ubuntu@${pub2} ubuntu@$priv2 -i $ssh_key
==============================
EOL



