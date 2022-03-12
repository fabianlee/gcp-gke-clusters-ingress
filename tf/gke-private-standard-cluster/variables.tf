
variable project {}
variable region {}
variable zone {}
variable vpc_network_name {}


##########  private cluster specific variables #############

variable cluster_name { }
variable cluster_version_prefix { }

variable enable_private_endpoint { default=false }
variable is_regional_cluster { default=false }

variable subnetwork_name {}
variable master_ipv4_cidr_block_28 { }
variable master_authorized_networks_cidr_list {
  type=list(string)
  default=[]
}

