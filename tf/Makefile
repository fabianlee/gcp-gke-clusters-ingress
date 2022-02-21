THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform
FLAGS := 
#--auto-approve

STD_DIR := gke-private-standard-cluster
AP_DIR := gke-private-autopilot-cluster

NETWORKS_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/networks.tfvars --state=../envs/networks.tfstate
CLOUDNAT_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/cloudnat.tfvars --state=../envs/cloudnat.tfstate
VMS_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/vms.tfvars --state=../envs/vms.tfstate

GKE_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate
PRIVGKE_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/std-prv-10-0-100-0.tfvars --state=../envs/std-prv-10-0-100-0.tfstate
AP_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/ap-pub-10-0-91-0.tfvars --state=../envs/ap-pub-10-0-91-0.tfstate
PRIVAP_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/ap-prv-10-0-101-0.tfvars --state=../envs/ap-prv-10-0-101-0.tfstate

init:

networks: init
	cd networks && $(TF) init
	cd networks && $(TF) apply $(NETWORKS_ARGS) $(FLAGS)
networks-destroy: init
	cd networks && $(TF) destroy $(NETWORKS_ARGS) $(FLAGS)

cloudnat: init
	cd cloudnat && $(TF) init
	cd cloudnat && $(TF) apply $(CLOUDNAT_ARGS) $(FLAGS)
cloudnat-destroy:
	cd cloudnat && $(TF) destroy $(CLOUDNAT_ARGS) $(FLAGS)

vms: init
	cd vms && $(TF) init
	cd vms && $(TF) apply $(VMS_ARGS) $(FLAGS)
vms-refresh:
	cd vms && $(TF) refesh $(VMS_ARGS)
vms-output:
	cd vms && $(TF) output -json --state=../envs/vms.tfstate | jq ".module_internal_ip.value"
	cd vms && $(TF) output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value"
vms-destroy:
	cd vms && $(TF) destroy $(VMS_ARGS) $(FLAGS)

gke: init
	cd $(STD_DIR) && $(TF) init
	cd $(STD_DIR) && $(TF) apply $(GKE_ARGS) $(FLAGS)
	#KUBECONFIG=../kubeconfig-std-pub-10-0-90-0 gcloud container clusters get-credentials std-pub-10-0-90-0
gke-destroy:
	cd $(STD_DIR) && $(TF) destroy $(GKE_ARGS) $(FLAGS)

ap: init
	cd $(AP_DIR) && $(TF) init
	cd $(AP_DIR) && $(TF) apply $(AP_ARGS) $(FLAGS)
	#KUBECONFIG=../kubeconfig-ap-pub-10-0-91-0 gcloud container clusters get-credentials ap-prv-10-0-101-0
ap-destroy:
	cd $(AP_DIR) && $(TF) destroy $(AP_ARGS) $(FLAGS)

privgke: init
	cd $(STD_DIR) && $(TF) init
	cd $(STD_DIR) && $(TF) apply $(PRIVGKE_ARGS) $(FLAGS)
	#KUBECONFIG=../kubeconfig-std-prv-10-0-100-0 gcloud container clusters get-credentials std-prv-10-0-100-0
privgke-destroy:
	cd $(STD_DIR) && $(TF) destroy $(PRIVGKE_ARGS) $(FLAGS)

privap: init
	cd $(AP_DIR) && $(TF) init
	cd $(AP_DIR) && $(TF) apply $(PRIVAP_ARGS) $(FLAGS)
	#KUBECONFIG=../kubeconfig-ap-prv-10-0-101-0 gcloud container clusters get-credentials ap-prv-10-0-101-0
privap-destroy:
	cd $(AP_DIR) && $(TF) destroy $(PRIVAP_ARGS) $(FLAGS)
