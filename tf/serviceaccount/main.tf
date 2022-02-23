# imported already existing seviceaccount using:
# terraform import --var-file=../envs/all.tfvars --var-file=../envs/serviceaccount.tfvars --state=../envs/serviceaccount.tfstate module.gcp-serviceaccount.google_service_account.svcaccount projects/my-gkeproj1-xxxx/serviceAccounts/tf-creator@my-gkeproj1-xxxx.iam.gserviceaccount.com

module "gcp-serviceaccount" {
  source = "../modules/gcp-serviceaccount"

  project = var.project
  service_account_name = var.service_account_name

}

output "svcaccount_json" {
  sensitive = true
  value = module.gcp-serviceaccount.svcaccount_json
}
