THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform
FLAGS := "--auto-approve"

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
	cd std-cluster && $(TF) init
	cd std-cluster && $(TF) apply --var-file=../envs/all.tfvars --var-file=../envs/gke.tfvars --state=../envs/gke.tfstate $(FLAGS)
gke-destroy:
	cd std-cluster && $(TF) destroy --var-file=../envs/all.tfvars --var-file=../envs/gke.tfvars --state=../envs/gke.tfstate $(FLAGS)
