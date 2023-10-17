THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform
INIT_FLAGS :=
# -upgrade (when provider version is upgraded)
FLAGS := 
#FLAGS := --auto-approve
#--auto-approve (if you want changes approved without prompt)

STD_DIR := gke-private-standard-cluster
AP_DIR := gke-private-autopilot-cluster

PROJECT_ARGS := --var-file=../envs/all.tfvars --state=../envs/project.tfstate
SVCACCT_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/serviceaccount.tfvars --state=../envs/serviceaccount.tfstate

NETWORKS_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/networks.tfvars --state=../envs/networks.tfstate
CLOUDNAT_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/cloudnat.tfvars --state=../envs/cloudnat.tfstate
VMS_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/vms.tfvars --state=../envs/vms.tfstate

# private standard cluster, publicly exposed
GKE_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate
# private Autopilot cluster, publicly exposed
AP_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/ap-pub-10-0-91-0.tfvars --state=../envs/ap-pub-10-0-91-0.tfstate
# private standard cluster, privately exposed only
PRIVGKE_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/std-prv-10-0-100-0.tfvars --state=../envs/std-prv-10-0-100-0.tfstate
# private Autopilot cluster, privately exposed only
PRIVAP_ARGS := --var-file=../envs/all.tfvars --var-file=../envs/ap-prv-10-0-101-0.tfvars --state=../envs/ap-prv-10-0-101-0.tfstate

init:

project: init
	@echo Creating the project is a bootstrapping function done as the editor or owner of project
	gcloud auth application-default login
	@echo Make sure quota project id is defined
	grep quota_project_id ~/.config/gcloud/application_default_credentials.json
	cd project && $(TF) init $(INIT_FLAGS)
	cd project && $(TF) apply $(PROJECT_ARGS) $(FLAGS)
	gcloud auth application-default set-quota-project `grep ^project_id ../global.properties | cut -d= -f2`
	gcloud config set billing/quota_project `grep ^project_id ../global.properties | cut -d= -f2`
project-destroy:
	cd project && $(TF) destroy $(PROJECT_ARGS) $(FLAGS)

svcaccount: init
	@echo Creating the service account is a bootstrapping function done as the editor or owner of project
	@echo You must run this first 'gcloud auth application-default login'
	cd serviceaccount && $(TF) init $(INIT_FLAGS)
	cd serviceaccount && $(TF) apply $(SVCACCT_ARGS) $(FLAGS)
svcaccount-output:
	cd serviceaccount && $(TF) output -raw --state=../envs/serviceaccount.tfstate svcaccount_json
svcaccount-destroy:
	cd serviceaccount && $(TF) destroy $(SVCACCT_ARGS) $(FLAGS)

networks: init
	cd networks && $(TF) init $(INIT_FLAGS)
	cd networks && $(TF) apply $(NETWORKS_ARGS) $(FLAGS)
networks-destroy: init
	cd networks && $(TF) destroy $(NETWORKS_ARGS) $(FLAGS)

cloudnat: init
	cd cloudnat && $(TF) init $(INIT_FLAGS)
	cd cloudnat && $(TF) apply $(CLOUDNAT_ARGS) $(FLAGS)
cloudnat-destroy:
	cd cloudnat && $(TF) destroy $(CLOUDNAT_ARGS) $(FLAGS)

vms: init
	cd vms && $(TF) init $(INIT_FLAGS)
	cd vms && $(TF) apply $(VMS_ARGS) $(FLAGS)
vms-refresh:
	cd vms && $(TF) refresh $(VMS_ARGS)
vms-output:
	cd vms && $(TF) output -json --state=../envs/vms.tfstate | jq ".module_internal_ip.value"
	cd vms && $(TF) output -json --state=../envs/vms.tfstate | jq ".module_public_ip.value"
vms-destroy:
	cd vms && $(TF) destroy $(VMS_ARGS) $(FLAGS)

gke: init
	cd $(STD_DIR) && $(TF) init $(INIT_FLAGS)
	cd $(STD_DIR) && $(TF) apply $(GKE_ARGS) $(FLAGS)
gke-destroy:
	cd $(STD_DIR) && $(TF) destroy $(GKE_ARGS) $(FLAGS)

ap: init
	cd $(AP_DIR) && $(TF) init $(INIT_FLAGS)
	cd $(AP_DIR) && $(TF) apply $(AP_ARGS) $(FLAGS)
ap-refresh: init
	cd $(AP_DIR) && $(TF) refresh $(AP_ARGS) $(FLAGS)
ap-destroy:
	cd $(AP_DIR) && $(TF) destroy $(AP_ARGS) $(FLAGS)

privgke: init
	cd $(STD_DIR) && $(TF) init $(INIT_FLAGS)
	cd $(STD_DIR) && $(TF) apply $(PRIVGKE_ARGS) $(FLAGS)
privgke-destroy:
	cd $(STD_DIR) && $(TF) destroy $(PRIVGKE_ARGS) $(FLAGS)

privap: init
	cd $(AP_DIR) && $(TF) init $(INIT_FLAGS)
	cd $(AP_DIR) && $(TF) apply $(PRIVAP_ARGS) $(FLAGS)
privap-destroy:
	cd $(AP_DIR) && $(TF) destroy $(PRIVAP_ARGS) $(FLAGS)
