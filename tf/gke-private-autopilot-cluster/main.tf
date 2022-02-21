
module "gcp-gke-private-autopilot-cluster" {
  source = "../modules/gcp-gke-private-autopilot-cluster"

  project = var.project
  region = var.region
  zone = var.zone
  vpc_network_name = var.vpc_network_name

  cluster_name = var.cluster_name
  enable_private_endpoint = var.enable_private_endpoint
  subnetwork_name = var.subnetwork_name
  master_ipv4_cidr_block_28 = var.master_ipv4_cidr_block_28

  master_authorized_networks_cidr_list = var.master_authorized_networks_cidr_list
  
}

