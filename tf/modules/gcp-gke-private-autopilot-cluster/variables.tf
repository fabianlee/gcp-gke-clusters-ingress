variable project {}
variable region {}
variable zone {}

variable vpc_network_name {}



##########  private Autopilot cluster specific variables #############

variable cluster_name { }

# whether kubectl endpoint available publicly
variable enable_private_endpoint { default = false }

variable subnetwork_name {}
variable secondary_range_services_name { default = "services" }
variable secondary_range_pods_name { default = "pods" }
variable master_ipv4_cidr_block_28 { }

# terraform says repair+upgrade must be true when REGULAR
variable cluster_version_prefix { default="1.21.5" }
variable cluster_release_channel { default="REGULAR" }

# authorized networks empty by default
variable master_authorized_networks_cidr_list { 
  type = list
  default=[] 
} 

variable node_ap_oauth_scopes {
  type = list(string)
  default = [
    "https://www.googleapis.com/auth/devstorage.read_only",
    "https://www.googleapis.com/auth/logging.write",
    "https://www.googleapis.com/auth/monitoring",
    "https://www.googleapis.com/auth/servicecontrol",
    "https://www.googleapis.com/auth/service.management.readonly",
    "https://www.googleapis.com/auth/trace.append"
  ]
}
variable node_ap_network_tags_list {
  type = list(string)
  default = ["gke-node"]
}
variable node_ap_labels_list {
  type = list(string)
  default = ["my-label"]
}

