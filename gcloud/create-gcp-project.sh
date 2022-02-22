#!/bin/bash
#
# Creates gcp project
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
project_name="$2"
if [[ -z "$project_id" || -z "$project_name" ]]; then
  echo "Usage: projectid projectName"
  exit 1
fi

current_user=$(gcloud config list --format="value(core.account)")
billing_account=$(gcloud alpha billing accounts list --format="value(name)")
[ -n "$billing_account" ] || { echo "ERROR you must setup a billing account in the Web console before continuing"; exit 3; }
echo "billing_account for $current_user is $billing_account"

project_count=$(gcloud projects list --filter="id=$project_id" --format="value(projectId)" | wc -l)
if [ $project_count -eq 0 ]; then
  gcloud config unset project
  gcloud projects create $project_id
  if [ $? -ne 0 ]; then
    echo "ERROR project could not be created, You might need to create a random project id. Run ./make_random_project_id.sh"
    exit 3
  fi
else
  echo "gcp project $project_id already exists"
fi
gcloud config set project $project_id

echo "add this project to billing account so services can start being enabled"
set -x
gcloud beta billing projects list --billing-account=$billing_account
gcloud beta billing projects link $project_id --billing-account=$billing_account
gcloud beta billing projects list --billing-account=$billing_account
set +x

# IAM roles for registering clusters as default compute engine service account
# not required for project owner who has all permissions
# but would be required if asmcli install with --enable-all done using gcloud logged in as default compute engine
# default auth on gcp VM instances in cloud scope is default compute engine
project_number=$(gcloud projects describe $project_id --format="value(projectNumber)")
gcloud projects add-iam-policy-binding $project_id \
   --member serviceAccount:${project_number}-compute@developer.gserviceaccount.com \
   --role=roles/gkehub.admin \
   --role=roles/iam.serviceAccountAdmin \
   --role=roles/iam.serviceAccountKeyAdmin \
   --role=roles/resourcemanager.projectIamAdmin \
   --role=roles/container.admin


