#!/bin/bash
#
# Wizard to show available actions
#
BIN_DIR=$(dirname ${BASH_SOURCE[0]})
cd $BIN_DIR

# visual marker for task
declare -A done_status

# BASH does not support multi-dimensional/complex datastructures
# 1st column = action
# 2nd column = description
menu_items=(
  "project,Create gcp project as self"
  "svcaccount,Create service account for provisioning"
  "network,Create network and subnets"
  ""
  "metadata,Load ssh key into project metadata"
  "vm,Create VM instances in subnets"
  "showssh,Show public IP and bastion config"
  ""
  "gke,Create public standard GKE cluster"
  "privgke,Create private standard GKE cluster"
  "autopilot,Create public AutoGKE cluster"
  "privautopilot,Create private AutoGKE cluster"
  ""
  "delcluster,Delete GKE standard cluster"
  "delauto,Delete GKE Autopilot cluster"
  "delvm,Delete VM instances"
  "delnetwork,Delete network and Cloud NAT"
)

function showMenu() {
  echo ""
  echo ""
  echo "==========================================================================="
  echo " MAIN MENU"
  echo "==========================================================================="
  echo ""
  
  for menu_item in "${menu_items[@]}"; do
    # skip empty lines
    [ -n "$menu_item" ] || { printf "\n"; continue; }

    menu_id=$(echo $menu_item | awk -F, '{print $1}')
    label=$(echo $menu_item | awk -F, '{print $2}')
    printf "%-16s %-50s %-12s\n" "$menu_id" "$label" "${done_status[$menu_id]}"

  done
  echo ""
} # showMenu


GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'
NF='\033[0m'
function echoGreen() {
  echo -e "${GREEN}$1${NC}"
}
function echoRed() {
  echo -e "${RED}$1${NC}"
}
function echoYellow() {
  echo -e "${YELLOW}$1${NC}"
}

function ensure_binary() {
  binary="$1"
  binpath=$(which $binary)
  if [ -z "$binpath" ]; then
    echo "ERROR you must install $binary before running this wizard"
    exit 1
  fi
}

function check_prerequisites() {

  # make sure binaries are installed 
  ensure_binary gcloud
  ensure_binary kubectl
  ensure_binary terraform

  # show binary versions
  # on apt, can be upgraded with 'sudo apt install --only-upgrade google-cloud-sdk -y'
  gcloud --version | grep 'Google Cloud SDK'
  terraform --version | head -n 1

  # check for gcloud login context
  gcloud projects list > /dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth login --no-launch-browser
  gcloud auth list

  # create personal credentials that terraform provider can use
  gcloud auth application-default print-access-token >/dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth application-default login

} # check_prerequisites


###### MAIN ###########################################


check_prerequisites "$@"

# bring in variables
source ./global.properties
echo "project_name is $project_name"
echo "cluster_version is $cluster_version"
echo "cluster release channel is $cluster_release_channel"

# loop where user can select menu items
lastAnswer=""
answer=""
while [ 1 == 1 ]; do
  showMenu
  test -t 0
  if [ ! -z $lastAnswer ]; then echo "Last action was '${lastAnswer}'"; fi
  read -p "Which action (q to quit) ? " answer
  echo ""

  case $answer in

    project)
      set -x
      gcloud/create-gcp-project.sh $project_id $project_name
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    svcaccount)
      set -x
      gcloud/create-tf-service-account.sh $project_id $project_name
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    network)
      set -x
      gcloud/create-network-and-subnets.sh $project_id $network_name $region
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    metadata)
      set -x
      gcloud/add-gcp-metadata-ssh-key.sh $project_id
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    vm)
      set -x
      retVal=0
      for subnet in pub-10-0-90-0 pub-10-0-91-0; do
        gcloud/create-vm-instance.sh public vm-$subnet $project_id $network_name $subnet $region
        [ $? -eq 0 ] || retVal=$?
      done
      for subnet in prv-10-0-100-0 prv-10-0-101-0; do
        gcloud/create-vm-instance.sh private vm-$subnet $project_id $network_name $subnet $region
        [ $? -eq 0 ] || retVal=$?
      done
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    showssh)
      set -x
      gcloud/show-ssh.sh $project_id $region
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    delcluster)
      set -x
      gcloud/delete-gke-cluster.sh $project_id standard
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delauto)
      set -x
      gcloud/delete_gke_cluster.sh $project_id autopilot
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delnetwork)
      set -x
      gcloud/delete-network.sh $project_id $network_name $region
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delvm)
      set -x
      retVal=0
      for subnet in pub-10-0-90-0 pub-10-0-91-0 prv-10-0-100-0 prv-10-0-101-0; do
        gcloud/delete-vm-instance.sh $project_id vm-$subnet $region
        [ $? -eq 0 ] || retVal=$?
      done

      set +x 
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delprivvm)
      set -x
      gcloud/delete-vm.sh $project_id vm-private $region
      retVal=$?
      set +x 
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    q|quit|0)
      echo "QUITTING"
      exit 0;;
    *)
      echoRed "ERROR that is not one of the options, $answer";;
  esac

  lastAnswer=$answer
  echo "press <ENTER> to continue..."
  read -p "" foo

done




