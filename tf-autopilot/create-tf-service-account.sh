#!/bin/bash
#
# Bootstrap script that creates service account for terraform, "tf-creator"
#
# if gcloud functions are slow, you may need to disable ipv6 temporarily
# permanent changes would need to go into /etc/sysctl.conf
# sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1
# sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1
#

path_to_gcloud=$(which gcloud)
if [ -z "$path_to_gcloud" ]; then
  echo "ERROR you must have gcloud installed to use this script, https://cloud.google.com/sdk/docs/install"
  exit 1
fi

# check if gcloud authentication exists
gcloud projects list >/dev/null 2>&1
loggedIn=($? -eq 0)
if [ $loggedIn -eq 0 ]; then
  loginAs=$(gcloud auth list 2>/dev/null | grep "*" | tr -d '/ //' | cut -c2-)
  echo "Already logged in as $loginAs"
else
  echo "ERROR not logged in.  Use 'gcloud auth login <accountName>'"
  exit 1
fi

# allow user to override project id as parameter
if [ -z $1 ]; then
  projectId=$(gcloud config get-value project)
else
  projectId="$1"
fi
[ -n "$projectId" ] || { echo "ERROR need to set project 'gcloud config set project' OR specify as param"; exit 4; }

# get project name
projectName=$(gcloud projects list --filter=id=$projectId --format="value(name)")
[ -n "$projectName" ] || { echo "ERROR could not find project named based on id $projectId, try 'gcloud projects list'"; exit 4; }
echo "project id: $projectId"
echo "project name: $projectName"
gcloud config set project $projectId

# creates service account if one does not exist
function create_svc_account() {

  project="$1"
  name="$2"
  descrip="$3"

  accountExists=$(gcloud iam service-accounts list --filter="name ~ ${name}@" | wc -l)
  if [ $accountExists == 0 ]; then
    echo "Going to create service account '$name' in projectId $projectId"
    gcloud iam service-accounts create $name --display-name "$descrip" --project=$projectId
    echo "going to sleep for 30 seconds to wait for eventual consistency of service account creation..."
    sleep 30
  else
    echo "The service account $name is already created in projectId $projectId"
  fi

  # download key if just created or local json does not exist
  if [[ $accountExists == 0 || ! -f $name.json ]]; then
    svcEmail=$(get_email $projectId $name)
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
  projectId="$1"
  name="$2"
  svcEmail=$(gcloud iam service-accounts list --project=$projectId --filter="name ~ ${name}@" --format="value(email)")
  echo $svcEmail
}

function assign_role() {
  projectId="$1"
  name="$2"
  roles="$3"

  svcEmail=$(get_email $projectId $name)
  echo "serviceAccountEmail: $svcEmail"

  savedIFS=$IFS
  IFS=' '
  for role in $roles; do
    set -ex
    gcloud projects add-iam-policy-binding $projectId --member=serviceAccount:$svcEmail --role=$role > /dev/null
    set +ex
  done
  IFS=$savedIFS

}

############## MAIN #########################################


create_svc_account $projectId "tf-creator" "terraform user"
# roles/iam.serviceAccountAdmin - to create other service accounts
# roles/compute.securityAdmin - for compute.firewalls.* (create)
# roles/compute.instanceAdmin - for compute.instances.* (create) and compute.disks.create
# roles/compute.networkAdmin - for compute.networks.* (create)
assign_role $projectId "tf-creator" "roles/iam.serviceAccountAdmin roles/resourcemanager.projectIamAdmin roles/storage.admin roles/compute.securityAdmin roles/compute.instanceAdmin roles/compute.networkAdmin"


