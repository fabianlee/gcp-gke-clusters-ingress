
variable project {}

# krmapihosting added for ACM, https://cloud.google.com/krmapihosting/docs/audit-logging
variable project_services_list {
  type = list(string)
  default = [ 
   "container.googleapis.com",
   "gkeconnect.googleapis.com",
   "gkehub.googleapis.com",
   "cloudresourcemanager.googleapis.com",
   "iam.googleapis.com",
   "anthos.googleapis.com",
   "krmapihosting.googleapis.com"
  ]
}


variable asm_services_list {
  type = list(string)
  default = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "cloudtrace.googleapis.com",
    "mesh.googleapis.com", # bundler for meshca,meshconfig,etc: https://cloud.google.com/service-mesh/docs/managed/provision-managed-anthos-service-mesh#expandable-1
    "serviceusage.googleapis.com",
    "meshca.googleapis.com",
    #"meshtelemetry.googleapis.com", # NO LONGER AVAILABLE
    "meshconfig.googleapis.com",
    "iamcredentials.googleapis.com",
    "gkeconnect.googleapis.com",
    "gkehub.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "stackdriver.googleapis.com"
   ]
}

# for user provided additional services
variable additional_services_list {
  type = list(string)
  default = []
}

