# imported already existing gcp project using:
# terraform import --var-file=../envs/all.tfvars --state=../envs/project.tfstate module.gcp-project.google_project.project my-gkeproj1-xxxx


# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
module "gcp-project" {
  source = "../modules/gcp-project"

  project = var.project
  additional_services_list = var.additional_services_list
}

output "mybilling" {
  value = module.gcp-project.mybilling
}
output "projnumber" {
  value = module.gcp-project.projnumber
}

