
module "gcp-serviceaccount" {
  source = "../modules/gcp-serviceaccount"

  project = var.project
  service_account_name = var.service_account_name

}

output "svcaccount_json" {
  sensitive = true
  value = module.gcp-serviceaccount.svcaccount_json
}
