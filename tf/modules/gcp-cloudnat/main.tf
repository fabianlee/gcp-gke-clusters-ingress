
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/compute_network
data "google_compute_network" "vpc_network" {
  name = var.vpc_network_name
}

# create a nat to allow private instances connect to internet
resource "google_compute_router" "nat-router" {
  name = "${data.google_compute_network.vpc_network.name}-router1"
  network = data.google_compute_network.vpc_network.name
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat
resource "google_compute_router_nat" "nat-gateway" {
  name    = "${data.google_compute_network.vpc_network.name}-nat-gateway1"
  router  = google_compute_router.nat-router.name

  nat_ip_allocate_option = "AUTO_ONLY"

  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES" 

  # if LIST_OF_SUBNETWORKS were defined above, then you must provide list
  #subnetwork { 
  #   name = google_compute_subnetwork.private_subnetwork.id
  #   source_ip_ranges_to_nat = [ var.private_cidr_block ] # "ALL_IP_RANGES"
  #}
}

