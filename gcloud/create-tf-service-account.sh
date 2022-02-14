#!/bin/bash
#
# Bootstrap script that creates service account for terraform, "tf-creator"
#
# if gcloud functions are slow, you may need to disable ipv6 temporarily
# permanent changes would need to go into /etc/sysctl.conf
# sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
# sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
# sudo sysctl -p
#


# creates service account if one does not exist
function create_svc_account() {
  project_id="$1"
  name="$2"
  descrip="$3"

  accountExists=$(gcloud iam service-accounts list --filter="name ~ ${name}@" | wc -l)
  if [ $accountExists == 0 ]; then
    echo "Going to create service account '$name' in project_id $project_id"
    gcloud iam service-accounts create $name --display-name "$descrip" --project=$project_id
    echo "going to sleep for 30 seconds to wait for eventual consistency of service account creation..."
    sleep 30
  else
    echo "The service account $name is already created in project_id $project_id"
  fi

  # download key if just created or local json does not exist
  if [[ $accountExists == 0 || ! -f $name.json ]]; then
    svcEmail=$(get_email $project_id $name)
    echo "serviceAccountEmail: $svcEmail"
    keyCount=$(gcloud iam service-accounts keys list --iam-account $svcEmail | wc -l)

    # create key if necessary
    # normal count of lines is 2 (because output has header and gcp has its own managed key)
    if [ $keyCount -lt 3 ]; then
      echo "going to create/download key since key count is less than 3"
      gcloud iam service-accounts keys create $name.json --iam-account $svcEmail
    else
      echo "SKIP key download, there is already an existing key and it can only be downloaded upon creation"
      echo "delete the key manually from console.cloud.google.com if you need it rerecreated"
    fi

  fi

}

function get_email() {
  project_id="$1"
  name="$2"
  svcEmail=$(gcloud iam service-accounts list --project=$project_id --filter="name ~ ${name}@" --format="value(email)")
  echo $svcEmail
}

function assign_role() {
  project_id="$1"
  name="$2"
  roles="$3"

  svcEmail=$(get_email $project_id $name)
  echo "serviceAccountEmail: $svcEmail"

  savedIFS=$IFS
  IFS=' '
  for role in $roles; do
    set -ex
    gcloud projects add-iam-policy-binding $project_id --member=serviceAccount:$svcEmail --role=$role > /dev/null
    set +ex
  done
  IFS=$savedIFS

}

############## MAIN #########################################


project_id="$1"
project_name="$2"
if [[ -z "$project_id" || -z "$project_name" ]]; then
  echo "Usage: projectid projectName"
  exit 1
fi
echo "project id: $project_id"
echo "project name: $project_name"
gcloud config set project $project_id

create_svc_account $project_id "tf-creator" "terraform user"
# roles/iam.serviceAccountAdmin - to create other service accounts
# roles/compute.securityAdmin - for compute.firewalls.* (create)
# roles/compute.instanceAdmin - for compute.instances.* (create) and compute.disks.create
# roles/compute.networkAdmin - for compute.networks.* (create)
# ADDITIONAL ROLES for Anthos Service Mesh
# https://cloud.google.com/service-mesh/docs/installation-permissions
# roles/gkehub.admin
# roles/meshconfig.admin
# roles/resourcemanager.projectIamAdmin
# roles/iam.serviceAccountAdmin
# roles/servicemanagement.admin
# roles/serviceusage.serviceUsageAdmin
# roles/privateca.admin
# roles/container.admin (provides RBAC as cluster-admin)
assign_role $project_id "tf-creator" "roles/iam.serviceAccountAdmin roles/resourcemanager.projectIamAdmin roles/storage.admin roles/compute.securityAdmin roles/compute.instanceAdmin roles/compute.networkAdmin"


