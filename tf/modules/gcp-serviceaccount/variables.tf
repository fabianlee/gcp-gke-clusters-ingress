
variable project { }

variable service_account_name { }

# email used if not overriden
variable service_account_display { default="" }

variable service_account_roles {
  type = list(string)
  default = [
  "roles/iam.serviceAccountAdmin",
  "roles/resourcemanager.projectIamAdmin",
  "roles/storage.admin",
  "roles/compute.securityAdmin",
  "roles/compute.instanceAdmin",
  "roles/compute.networkAdmin",
  "roles/iam.serviceAccountUser",
  "roles/pubsub.editor",
  "roles/gkehub.admin",
  "roles/meshconfig.admin",
  "roles/resourcemanager.projectIamAdmin",
  "roles/iam.serviceAccountAdmin",
  "roles/servicemanagement.admin",
  "roles/serviceusage.serviceUsageAdmin",
  "roles/privateca.admin",
  "roles/container.admin",
  "roles/iam.workloadIdentityUser"
  ]
}

