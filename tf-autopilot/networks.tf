
resource "google_compute_network" "wg_network" {
  name = "wg-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wg_subnetwork" {
  provider      = google-beta

  name          = "wg-subnetwork"
  ip_cidr_range = var.cidr_block
  region        = var.region
  network       = google_compute_network.wg_network.name

  #https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_subnetwork
  #purpose       = "PUBLIC"

  depends_on = [google_compute_network.wg_network]
}
resource "google_compute_subnetwork" "private_subnetwork" {
  provider      = google-beta

  name          = "private-subnetwork"
  ip_cidr_range = var.private_cidr_block
  region        = var.region
  network       = google_compute_network.wg_network.name
  purpose       = "PRIVATE"

  depends_on = [google_compute_network.wg_network]
}

# create a public ip for nat service
resource "google_compute_address" "nat-ip" {
  name = "nat-ip"
  project = var.project
  region  = var.region
}
# create a nat to allow private instances connect to internet
resource "google_compute_router" "nat-router" {
  name = "nat-router"
  network = google_compute_network.wg_network.name
}
resource "google_compute_router_nat" "nat-gateway" {
  name = "nat-gateway"
  router = google_compute_router.nat-router.name

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips = [ google_compute_address.nat-ip.self_link ]

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS" #"ALL_SUBNETWORKS_ALL_IP_RANGES" 
  subnetwork { 
     name = google_compute_subnetwork.private_subnetwork.id
     source_ip_ranges_to_nat = [ var.private_cidr_block ] # "ALL_IP_RANGES"
  }
  depends_on = [ google_compute_address.nat-ip ]
}


resource "google_compute_firewall" "wg-firewall" {
  depends_on = [google_compute_subnetwork.wg_subnetwork]

  name    = "default-allow-wg"
  network = "wg-network"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  allow {
    protocol = "udp"
    ports    = ["51820"]
  }
  allow {
    protocol = "icmp"
  }

  // Allow traffic from everywhere to instances with tag
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["wg-server"]
}

resource "google_compute_firewall" "web-firewall" {
  depends_on = [google_compute_subnetwork.private_subnetwork]

  name    = "default-allow-web"
  network = "wg-network"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "tcp"
    ports    = ["80"]
  }
  allow {
    protocol = "icmp"
  }

  // traffic could come from public subnet or wireguard cidr block
  // we will just be wide here
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

