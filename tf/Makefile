THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform
FLAGS := ""
#"--auto-approve"

STD_DIR := gke-private-standard-cluster
AP_DIR := gke-private-autopilot-cluster

GKE_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate
PRIVGKE_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/std-prv-10-0-100-0.tfvars --state=../envs/std-prv-10-0-100-0.tfstate

AP_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/ap-pub-10-0-91-0.tfvars --state=../envs/ap-pub-10-0-91-0.tfstate
PRIVAP_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/ap-prv-10-0-101-0.tfvars --state=../envs/ap-prv-10-0-101-0.tfstate


init:

networks: init
	cd networks && $(TF) init
	cd networks && $(TF) apply --var-file=../envs/terraform.tfvars --state=../envs/networks.tfstate $(FLAGS)
networks-destroy: init
	cd networks && $(TF) destroy --var-file=../envs/terraform.tfvars --state=../envs/networks.tfstate $(FLAGS)

cloudnat: init
	cd cloudnat && $(TF) init
	cd cloudnat && $(TF) apply --var-file=../envs/terraform.tfvars --state=../envs/cloudnat.tfstate $(FLAGS)
cloudnat-destroy:
	cd cloudnat && $(TF) destroy --var-file=../envs/terraform.tfvars --state=../envs/cloudnat.tfstate $(FLAGS)

vms: init
	cd vms && $(TF) init
	cd vms && $(TF) apply --var-file=../envs/terraform.tfvars --state=../envs/vms.tfstate $(FLAGS)
vms-refresh:
	cd vms && $(TF) refresh --var-file=../envs/terraform.tfvars --state=../envs/vms.tfstate
vms-output:
	cd vms && $(TF) output -json --state=../envs/vms.tfstate | jq ".module_internal_ip.value"
	cd vms && $(TF) output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value"
vms-destroy:
	cd vms && $(TF) destroy --var-file=../envs/terraform.tfvars --state=../envs/vms.tfstate $(FLAGS)

gke: init
	cd $(STD_DIR) && $(TF) init
	cd $(STD_DIR) && $(TF) apply $(GKE_ARGS) $(FLAGS)
gke-destroy:
	cd $(STD_DIR) && $(TF) destroy $(GKE_ARGS) $(FLAGS)

privgke: init
	cd gke-private-standard-cluster && $(TF) init
	cd gke-private-standard-cluster && $(TF) apply --var-file=../envs/all.tfvars --var-file=../envs/gke-private-prv-endpoint.tfvars --state=../envs/gke-private-prv-endpoint.tfstate $(FLAGS)
privgke-destroy:
	cd gke-private-standard-cluster && $(TF) destroy --var-file=../envs/all.tfvars --var-file=../envs/gke-private-prv-endpoint.tfvars --state=../envs/gke-private-prv-endpoint.tfstate $(FLAGS)


autopilot: init
	cd gke-private-standard-cluster && $(TF) init
	cd gke-private-standard-cluster && $(TF) apply --var-file=../envs/all.tfvars --var-file=../envs/gke-private-pub-endpoint.tfvars --state=../envs/gke-private-pub-endpoint.tfstate $(FLAGS)
autopilot-destroy:
	cd gke-private-standard-cluster && $(TF) destroy --var-file=../envs/all.tfvars --var-file=../envs/gke-private-pub-endpoint.tfvars --state=../envs/gke-private-pub-endpoint.tfstate $(FLAGS)

