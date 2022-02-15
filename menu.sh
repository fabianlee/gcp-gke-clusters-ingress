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
  "project,Create gcp project"
  "svcaccount,Create service account for provisioning"
  "network,Create network, subnets, and firewall"
  "cloudnat,Create Cloud NAT for public egress of private IP"
  ""
  "metadata,Load ssh key into project metadata"
  "vms,Create VM instances in subnets"
  "enablessh,Setup ssh config for bastions and ansible inventory"
  "ssh,SSH into jumpbox"
  ""
  "ansibleping,Test ansible connection to public and private vms"
  "ansibleplay,Apply ansible playbook of minimal pkgs/utils for vms"
  ""
  "gke,Create public standard GKE cluster"
  "autopilot,Create public AutoGKE cluster"
  "privgke,Create private standard GKE cluster"
  "privautopilot,Create private AutoGKE cluster"
  ""
  "kubeconfigcopy,Copy kubeconfig to remote jumpboxes"
  "kubeconfig,Select KUBECONFIG \$MYKUBECONFIG"
  "k8s-register,Register with hub and get fleet identity"
  "k8s-scale,Apply balloon pod to warm up cluster"
  "k8s-tinytools,Apply tiny-tools Daemonset to cluster"
  "k8s-ASM,Install ASM on cluster"
  "k8s-certs,Create and load TLS certificates"
  "k8s-ASM-IGW,Install ASM Ingress Gateways on cluster"
  "k8s-gcp-lb,Deploy GCP HTTPS Loadbalancer using Ingress"
  "k8s-testapp,Install test service at /hello"
  "k8s-curl,Use curl to test /hello"
  ""
  "delgke,Delete GKE public standard cluster"
  "delautopilot,Delete GKE public Autopilot cluster"
  "delprivgke,Delete GKE private standard cluster"
  "delprivautopilot,Delete GKE private Autopilot cluster"
  ""
  "delvms,Delete VM instances"
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

    menu_id=$(echo $menu_item | cut -d, -f1)
    # eval done so that embedded variables get evaluated (e.g. MYKUBECONFIG)
    label=$(eval echo $menu_item | cut -d, -f2-)
    printf "%-16s %-60s %-12s\n" "$menu_id" "$label" "${done_status[$menu_id]}"

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
  install_instructions="$2"
  binpath=$(which $binary)
  if [ -z "$binpath" ]; then
    echo "ERROR you must install $binary before running this wizard"
    echo "$install_instructions"
    exit 1
  fi
}

function check_prerequisites() {

  # make sure binaries are installed 
  ensure_binary gcloud "install https://cloud.google.com/sdk/docs/install"
  ensure_binary kubectl "install https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/"
  ensure_binary terraform "install https://fabianlee.org/2021/05/30/terraform-installing-terraform-manually-on-ubuntu/"
  ensure_binary ansible "install https://fabianlee.org/2021/05/31/ansible-installing-the-latest-ansible-on-ubuntu/"
  ensure_binary yq "download from https://github.com/mikefarah/yq/releases"
  ensure_binary jq "run 'sudo apt install jq'"

  # show binary versions
  # on apt, can be upgraded with 'sudo apt install --only-upgrade google-cloud-sdk -y'
  gcloud --version | grep 'Google Cloud SDK'
  terraform --version | head -n 1
  ansible --version | head -n1
  yq --version
  jq --version

  # check for gcloud login context
  gcloud projects list > /dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth login --no-launch-browser
  gcloud auth list

  # create personal credentials that terraform provider can use
  gcloud auth application-default print-access-token >/dev/null 2>&1
  [ $? -eq 0 ] || gcloud auth application-default login

} # check_prerequisites


###### MAIN ###########################################


# if kubeconfig optionally specified on command line
MYKUBECONFIG="$1"
if [[ -n "$MYKUBECONFIG" && -f $MYKUBECONFIG ]]; then
  MYJUMPBOX="vm-$(echo $MYKUBECONFIG | cut -d- -f3-)"
  echo "MYKUBECONFIG = $MYKUBECONFIG"
  echo "MYJUMPBOX = $MYJUMPBOX"
fi

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
      gcloud/create-network-and-subnets.sh $project_id $network_name $region $firewall_internal_allow_cidr
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    cloudnat)
      set -x
      gcloud/create-cloud-nat.sh $project_id $network_name $region
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

    vms)
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

    enablessh)
      set -x
      gcloud/enable-ssh.sh $project_id $region
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    ssh)
      retVal=0
      echo "1. vm-pub-10-0-90-0"
      echo "2. vm-pub-10-0-91-0"
      echo "3. vm-prv-10-0-100-0"
      echo "4. vm-prv-10-0-101-0"
      echo ""
      read -p "ssh into which jumpbox ? " which_jumpbox

      case $which_jumpbox in
        1) jumpbox=vm-pub-10-0-90-0
        ;;
        2) jumpbox=vm-pub-10-0-91-0
        ;;
        3) jumpbox=vm-prv-10-0-100-0
        ;;
        4) jumpbox=vm-prv-10-0-101-0
        ;;
        *)
          echo "ERROR did not recognize which $which_jumpbox, valid choices 1-4"
          retVal=1
        ;;
      esac

      if [ $retVal -eq 0 ]; then
        set -x
        gcloud/ssh-into-jumpbox.sh $project_id $jumpbox $region
        retVal=$?
        set +x
      fi

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    ansibleping)
      set -x
      ansible -m ping all
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    ansibleplay)
      set -x
      ansible-galaxy collection install -r playbooks/requirements.yaml
      ansible-playbook playbooks/playbook-jumpbox-setup.yaml -l jumpboxes
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    gke)
      subnet=pub-10-0-90-0
      master_cidr="10.1.0.0/28"
      additional_authorized_cidr=""
      set -x
      gcloud/create-gke-cluster.sh standard public std-$subnet $cluster_version $cluster_release_channel $node_image_type $project_id $network_name $subnet "$master_cidr" "$additional_authorized_cidr" $region $is_regional_cluster
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
 
    autopilot)
      subnet=pub-10-0-91-0
      master_cidr="10.1.0.16/28"
      additional_authorized_cidr=""
      set -x
      gcloud/create-gke-cluster.sh autopilot public ap-$subnet $cluster_version $cluster_release_channel $node_image_type $project_id $network_name $subnet "$master_cidr" "$additional_authorized_cidr" $region $is_regional_cluster
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    privgke)
      subnet=prv-10-0-100-0
      master_cidr="10.1.0.32/28"
      additional_authorized_cidr="10.0.90.0/24"
      set -x
      gcloud/create-gke-cluster.sh standard private std-$subnet $cluster_version $cluster_release_channel $node_image_type $project_id $network_name $subnet "$master_cidr" "$additional_authorized_cidr" $region $is_regional_cluster
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    privautopilot)
      subnet=prv-10-0-101-0
      master_cidr="10.1.0.48/28"
      additional_authorized_cidr="10.0.91.0/24"
      set -x
      gcloud/create-gke-cluster.sh autopilot private ap-$subnet $cluster_version $cluster_release_channel $node_image_type $project_id $network_name $subnet "$master_cidr" "$additional_authorized_cidr" $region $is_regional_cluster
      retVal=$?
      set +x

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    kubeconfigcopy)
      set -x
      ansible-playbook playbooks/playbook-copy-kubeconfig-remotely.yaml -l localhost,jumpboxes
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    kubeconfig)
      retVal=0
      echo "1. std-pub-10-0-90-0"
      echo "2. ap-pub-10-0-91-0"
      echo "3. std-prv-10-0-100-0"
      echo "4. ap-prv-10-0-101-0"
      echo ""
      read -p "Which kubectl ? " which_kubectl

      case $which_kubectl in
        1) kfile=kubeconfig-std-pub-10-0-90-0
        ;;
        2) kfile=kubeconfig-ap-pub-10-0-91-0
        ;;
        3) kfile=kubeconfig-std-prv-10-0-100-0
        ;;
        4) kfile=kubeconfig-ap-prv-10-0-101-0
        ;;
        *)
          echo "did not recognize which $which_kubectl, valid choices 1-4"
          retVal=1
        ;;
      esac

      if [ $retVal -eq 0 ]; then
        if [ -f $kfile ]; then
          MYKUBECONFIG=$kfile
          MYJUMPBOX="vm-$(echo $MYKUBECONFIG | cut -d- -f3-)"
          echo "MYKUBECONFIG = $MYKUBECONFIG"
          echo "MYJUMPBOX = $MYJUMPBOX"
        else
          echo "ERROR selecting $kfile because the file does not exist"
        fi
      fi

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    k8s-register)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-gcloud-register-fleet.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-tinytools)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-tinytools.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 
      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-scale)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-balloon-scale.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-ASM)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-ASM.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-certs)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-certs.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-ASM-IGW)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-ASM-IngressGateway.yaml -l $MYJUMPBOX --extra-vars "remote_kubeconfig=$MYKUBECONFIG"
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-gcp-lb)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-GCP-loadbalancer.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-testapp)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-testapp.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    k8s-curl)
      [ -n "$MYKUBECONFIG" ] || { read -p "ERROR select a KUBECONFIG first. Press <ENTER>" dummy; continue; }
      set -x
      ansible-playbook playbooks/playbook-k8s-curl.yaml -l $MYJUMPBOX --extra-vars remote_kubeconfig=$MYKUBECONFIG
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;

    delgke)
      set -x
      gcloud/delete-gke-cluster.sh $project_id std-pub-10-0-90-0 $region $is_regional_cluster
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delautopilot)
      set -x
      gcloud/delete-gke-cluster.sh $project_id ap-pub-10-0-91-0 $region 1
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delprivgke)
      set -x
      gcloud/delete-gke-cluster.sh $project_id std-prv-10-0-100-0 $region $is_regional_cluster
      retVal=$?
      set +x 

      [ $retVal -eq 0 ] && done_status[$answer]="OK" || done_status[$answer]="ERR"
      ;;
    delprivautopilot)
      set -x
      gcloud/delete-gke-cluster.sh $project_id ap-prv-10-0-101-0 $region 1
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
    delvms)
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




