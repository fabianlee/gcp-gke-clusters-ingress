# examples of import
# terraform import --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate module.gcp-gke-private-standard-cluster.google_compute_security_policy.security-policy std-pub-10-0-90-0-security-policy
# terraform import --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate module.gcp-gke-private-standard-cluster.google_compute_ssl_policy.ssl-policy std-pub-10-0-90-0-ssl-policy
# terraform import --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate module.gcp-gke-private-standard-cluster.google_pubsub_topic.cluster_topic std-pub-10-0-90-0


module "gcp-gke-private-standard-cluster" {
  source = "../modules/gcp-gke-private-standard-cluster"

  project = var.project
  region = var.region
  zone = var.zone
  vpc_network_name = var.vpc_network_name

  cluster_name = var.cluster_name
  cluster_version_prefix = var.cluster_version_prefix
  enable_private_endpoint = var.enable_private_endpoint
  is_regional_cluster = var.is_regional_cluster
  subnetwork_name = var.subnetwork_name
  master_ipv4_cidr_block_28 = var.master_ipv4_cidr_block_28

  master_authorized_networks_cidr_list = var.master_authorized_networks_cidr_list
  
}

output "cluster_name" {
  value = module.gcp-gke-private-standard-cluster.cluster_name
}

