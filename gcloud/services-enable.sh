#!/bin/bash
#
# enables all ervice apis needed for GKE+ASM at project level
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

project_id="$1"
if [[ -z "$project_id" ]]; then
  echo "Usage: projectid"
  exit 1
fi

gcloud config set project $project_id

echo "enable apis for fleet workload identity"
gcloud services enable --project=$project_id \
   container.googleapis.com \
   gkeconnect.googleapis.com \
   gkehub.googleapis.com \
   cloudresourcemanager.googleapis.com \
   iam.googleapis.com \
   anthos.googleapis.com

echo "anthos service mesh services"
gcloud services enable \
    --project=$project_id \
    container.googleapis.com \
    compute.googleapis.com \
    monitoring.googleapis.com \
    logging.googleapis.com \
    cloudtrace.googleapis.com \
    meshca.googleapis.com \
    meshtelemetry.googleapis.com \
    meshconfig.googleapis.com \
    iamcredentials.googleapis.com \
    gkeconnect.googleapis.com \
    gkehub.googleapis.com \
    cloudresourcemanager.googleapis.com \
    stackdriver.googleapis.com
