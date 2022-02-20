

module "gcp-networks" {
  source = "../modules/gcp-networks"

  vpc_network_name = var.vpc_network_name
  subnetwork_region = var.region
  firewall_internal_allow_cidr = var.firewall_internal_allow_cidr
}

