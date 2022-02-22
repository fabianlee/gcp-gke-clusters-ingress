
data "google_billing_account" "acct" {
  display_name = "My Billing Account"
  open         = true
}

resource "google_project" "project" {
  name       = var.project
  project_id = var.project

  # if set to false, will delete 'default'
  # this leaves networking in current state
  auto_create_network = true

  billing_account = data.google_billing_account.acct.id
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
resource "google_project_service" "services" {
  for_each = toset(var.project_services_list)

  project = var.project
  service = each.value

  disable_dependent_services = true
}

resource "google_project_service" "asm-services" {
  for_each = toset(var.asm_services_list)

  project = var.project
  service = each.value

  disable_dependent_services = true
}

resource "google_project_service" "additional-services" {
  for_each = toset(var.additional_services_list)

  project = var.project
  service = each.value

  disable_dependent_services = true
}


output "mybilling" {
  value = data.google_billing_account.acct.id
}
output "projnumber" {
  value = google_project.project.number
}
