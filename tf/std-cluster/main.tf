
# network
data "google_compute_network" "vpc" {
  name                    = var.vpc_network_name
}

# subnetwork
data "google_compute_subnetwork" "subnet" {
  name          = var.subnetwork_name
  region        = var.region
}

# pubsub for upgrade notifications
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic
resource "google_pubsub_topic" "cluster_topic" {
  name     = "std-${var.subnetwork_name}"
  message_retention_duration = "86600s"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
#resource "google_project_service" "services" {
#  project = variable.project
#  service = "iam.googleapis.com"
#
#  timeouts {
#    create = "30m"
#    update = "40m"
#  }
#
#  disable_dependent_services = true
#}

# available cluster versions
data "google_container_engine_versions" "cluster_versions" {
  location = var.region
  version_prefix = var.cluster_version_prefix
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster
resource "google_container_cluster" "cluster" {
  provider = google-beta
  name     = var.cluster_name
  location = var.is_regional_cluster ? var.region:var.zone
  min_master_version  = data.google_container_engine_versions.cluster_versions.latest_master_version

  release_channel {
    channel = var.cluster_release_channel
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  network =  data.google_compute_network.vpc.name
  subnetwork = data.google_compute_subnetwork.subnet.name

  # private worker nodes
  private_cluster_config {
    enable_private_nodes = var.enable_private_nodes
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block = var.master_ipv4_cidr_block_28
  }

  notification_config {
    pubsub {
      enabled = true
      topic = google_pubsub_topic.cluster_topic.id
    }
  }

  master_authorized_networks_config {

    # dynamic allows for no additional auth networks
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks_cidr_list
      content {
        display_name = "authnet ${each.value}"
        cidr_block = each.value
      }
    }

  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }
  maintenance_policy {
    recurring_window {
      start_time = "2022-01-28T10:00:00Z" # UTC
      end_time = "2022-01-28T14:00:00Z" # UTC
      recurrence = "FREQ=WEEKLY;BYDAY=TU,WE,TH,FR,SA,SU"
    }
  }

}

  # use names of secondary ranges
  ip_allocation_policy {
    cluster_secondary_range_name = "pods"
    services_secondary_range_name = "services"
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }


}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.cluster.name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.id
  initial_node_count = var.gke_num_nodes
  version  = data.google_container_engine_versions.cluster_versions.latest_node_version

  node_config {
    disk_size_gb = 60
    #image_type = var.node_image_type
    oauth_scopes = var.node_oauth_scopes

    preemptible  = var.node_preemptible

    # use smaller for regional cluster that has more nodes
    machine_type = var.is_regional_cluster ? "e2-standard-2":var.node_machine_type_large

    # network tags are for firewalls
    tags         = ["gke-node"]
    
    # kubernetes labels added to each node
    labels = {
      cluster = google_container_cluster.cluster.name
    }

    metadata = {
      disable-legacy-endpoints = "true"
    }

    // Enable workload identity on this node pool.
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

  }

  management {
    auto_repair = var.node_auto_repair
    auto_upgrade = var.node_auto_upgrade
  }
  upgrade_settings {
    max_surge = 2
    max_unavailable = 1
  }


}
