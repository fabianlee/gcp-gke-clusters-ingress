is_regional_cluster = false
subnetwork_name = "pub-10-0-100-0"

# gcloud container get-server-config --region=us-east1
cluster_name = "std-prv-10-0-100-0"
cluster_version_prefix = "1.21.5"
cluster_release_channel = "REGULAR" # REGULAR|RAPID|STABLE|UNSPECIFIED

enable_private_nodes = true
master_ipv4_cidr_block_28 = "10.1.32.0/28"

# false means it has public kubeapi endpoint
# true means it is private endpoint
enable_private_endpoint = true

