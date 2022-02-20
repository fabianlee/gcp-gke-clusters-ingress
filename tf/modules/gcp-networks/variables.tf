
variable vpc_network_name {}
variable subnetwork_region {}
variable firewall_internal_allow_cidr { default="10.0.0.0/8" }

variable "subnetworks" {
  type = map
  default = {
    "pub-10-0-90-0" = { cidr="10.0.90.0/24",pods_cidr="10.126.0.0/17",services_cidr="10.128.0.0/19",purpose="PRIVATE" },
    "pub-10-0-91-0" = { cidr="10.0.91.0/24",pods_cidr="10.126.128.0/17",services_cidr="10.128.32.0/19",purpose="PRIVATE"  },
    "prv-10-0-100-0" = { cidr="10.0.100.0/24",pods_cidr="10.127.0.0/17",services_cidr="10.128.64.0/19",purpose="PRIVATE" },
    "prv-10-0-101-0" = { cidr="10.0.101.0/24",pods_cidr="10.127.128.0/17",services_cidr="10.128.96.0/19",purpose="PRIVATE" }
  }

}

