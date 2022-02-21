variable project {}
variable region {}
variable zone {}

variable vpc_network_name {}

variable cluster_name { }
variable is_regional_cluster { default=false }
variable subnetwork_name {}
variable gke_num_nodes { default=1 }

variable cluster_version_prefix { default="1.21.5" }

# terraform says repair+upgrade must be true when REGULAR
# is this true in gcloud?
variable cluster_release_channel { default="REGULAR" }
variable node_auto_repair { default = true }
variable node_auto_upgrade { default = true }


# authorized networks empty by default
variable master_authorized_networks_cidr_list { 
  type = list
  default=[] 
} 

variable node_machine_type_large { default="e2-standard-4" }
variable node_preemptible { default=true }
variable node_image_type { default = "COS" }
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

# by default, worker nodes have private IP
variable enable_private_nodes { default = true }
# used when enable_private_nodes is true
variable master_ipv4_cidr_block_28 { }

# by default, kubectl endpoint available publicly
variable enable_private_endpoint { default = false }

