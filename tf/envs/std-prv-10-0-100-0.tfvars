is_regional_cluster = false
subnetwork_name = "prv-10-0-100-0"

# gcloud container get-server-config --region=us-east1
cluster_name = "std-prv-10-0-100-0"

master_ipv4_cidr_block_28 = "10.1.0.32/28"

# false means it has public kubeapi endpoint
# true means it is private endpoint
enable_private_endpoint = true

# can reach private endpoint via this additinal network
master_authorized_networks_cidr_list = ["10.0.90.0/24"]
