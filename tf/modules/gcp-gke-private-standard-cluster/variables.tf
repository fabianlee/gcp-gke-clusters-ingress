variable project {}
variable region {}
variable zone {}

variable vpc_network_name {}



##########  private cluster specific variables #############

variable cluster_name { }
variable is_regional_cluster { default=false }

# kubectl endpoint available publicly
variable enable_private_endpoint { default = false }

variable subnetwork_name {}
variable secondary_range_services_name { default = "services" }
variable secondary_range_pods_name { default = "pods" }
variable master_ipv4_cidr_block_28 { }

# terraform says repair+upgrade must be true when REGULAR
variable cluster_version_prefix { default="1.24.10" }
variable cluster_release_channel { default="REGULAR" }
variable node_auto_repair { default = true }
variable node_auto_upgrade { default = true }

# authorized networks empty by default
variable master_authorized_networks_cidr_list { 
  type = list
  default=[] 
} 

# larger machine for zonal since it may only have single node
variable node_machine_type_regional { default="e2-standard-4" }
variable node_machine_type_zonal { default="e2-standard-4" }

variable node_initial_node_count { default=1 }
variable node_preemptible { default=true }
variable node_image_type { default = "COS_CONTAINERD" }
variable node_disk_size_gb { default = 60 }
variable node_oauth_scopes {
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
variable node_network_tags_list {
  type = list(string)
  default = ["gke-node"]
}

variable nodes_max_surge { default = 2 }
variable nodes_max_unavailable { default = 1 }

