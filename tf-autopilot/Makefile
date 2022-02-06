THISDIR := $(notdir $(CURDIR))
PROJECT := $(THISDIR)
TF := terraform

apply: init 
	$(TF) apply -auto-approve

init: create-keypair
	## skips init if .terraform directory already exists
	[ -d .$(TF) ] || $(TF) init

## public/private keypair for ssh
create-keypair:
	[ -f id_rsa ] || ssh-keygen -t rsa -b 4096 -f id_rsa -C $(PROJECT) -N "" -q
	[ -f tf-creator.json ] || { echo "ERROR, create gcp service account 'tf-creator'"; exit 1; }

destroy:
	@echo "destroying compute instances first, which avoids errors due to timing"
	$(TF) destroy -target google_compute_instance.web -target google_compute_instance.wgserver -auto-approve
	@echo "waiting 60 seconds for vm instance deletion..."
	sleep 60
	$(TF) destroy -auto-approve
	ssh-keygen -f ~/.ssh/known_hosts -R 172.17.2.129
	##rm terraform.tfstate*

refresh:
	$(TF) refresh

output:
	$(TF) output
