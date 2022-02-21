# if this has public endpoint, you can grab kubeconfig
# cluster_name=tfstd-pub-10-0-91-0
# KUBECONFIG=kubeconfig-$cluster_name gcloud container clusters get-credentials $cluster_name --zone=us-east1-b


module "gcp-gke-private-cluster" {
  source = "../modules/gcp-gke-private-cluster"

  project = var.project
  region = var.region
  zone = var.zone
  vpc_network_name = var.vpc_network_name

  cluster_name = var.cluster_name
  enable_private_endpoint = var.enable_private_endpoint
  is_regional_cluster = var.is_regional_cluster
  subnetwork_name = var.subnetwork_name
  master_ipv4_cidr_block_28 = var.master_ipv4_cidr_block_28

  master_authorized_networks_cidr_list = var.master_authorized_networks_cidr_list
  
}

