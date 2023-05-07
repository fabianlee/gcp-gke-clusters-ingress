# terraform import --var-file=../envs/all.tfvars --var-file=../envs/std-pub-10-0-90-0.tfvars --state=../envs/std-pub-10-0-90-0.tfstate module.gcp-gke-private-standard-cluster.google_compute_security_policy.security-policy

# network
data "google_compute_network" "vpc" {
  name                    = var.vpc_network_name
}

# subnetwork
data "google_compute_subnetwork" "subnet" {
  name          = var.subnetwork_name
  region        = var.region
}

# pubsub topic for upgrade notifications
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic
resource "google_pubsub_topic" "cluster_topic" {
  name     = "std-${var.subnetwork_name}"
  message_retention_duration = "86600s"
}

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

  # worker nodes with private IP addresses
  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block = var.master_ipv4_cidr_block_28
    master_global_access_config {
      enabled = true
    }
  }

  notification_config {
    pubsub {
      enabled = true
      topic = google_pubsub_topic.cluster_topic.id
    }
  }

  # if this block exists at all, the "control plane for auth networks" will be enabled, but have no networks
  # so we need nested dynamic to represent
  # --no-enable-master-authorized-networks
  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks_cidr_list)>0 ? [1]:[]
    content {

      # dynamic inner block to list authorized networks
      dynamic "cidr_blocks" {
        for_each =  var.master_authorized_networks_cidr_list
        # notice the name inside is not 'each', it is name of dynamic block
        content {
          cidr_block = cidr_blocks.value
          display_name = "authnetworks ${cidr_blocks.value}"
        }
      } # end dynamic cidr_blocks

    } # end content of master_authorized_networks_config

  } # end dynamic block master_authorized_networks_config

  # --enable-intra-node-visibility
  enable_intranode_visibility = true

  addons_config {
    # wanted by ASM
    http_load_balancing {
      disabled = false
    }

    # beta, enabled
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }

    # this is default value, just making explicit.  inherited by nodes
    network_policy_config {
      disabled = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = "2022-01-28T10:00:00Z" # UTC
      end_time = "2022-01-28T14:00:00Z" # UTC
      recurrence = "FREQ=WEEKLY;BYDAY=TU,WE,TH,FR,SA,SU"
    }
  }

  # cluster labels 
  resource_labels = var.resource_labels

  # ignore cluster level label changes
  lifecycle {
    ignore_changes = [
      resource_labels
    ]
  }

  # references names of secondary ranges
  # this enables ip aliasing '--enable-ip-alias'
  ip_allocation_policy {
    services_secondary_range_name = var.secondary_range_services_name
    cluster_secondary_range_name = var.secondary_range_pods_name
  }

  workload_identity_config {
    workload_pool = "${var.project}.svc.id.goog"
  }

  # creates local kubeconfig file
  provisioner "local-exec" {
    command = <<EOT
      gcloud container clusters get-credentials ${var.cluster_name} ${ var.is_regional_cluster ? "--region=${var.region}" : "--zone=${var.region}-b" }
EOT
    environment = {
                   "KUBECONFIG" = "kubeconfig-${var.cluster_name}"
                  }
    working_dir = "${path.module}/../../.."
    on_failure  = continue
  }

  # deletes local kubeconfig file
  provisioner "local-exec" {
    when        = destroy
    # does not have access to var, only self's attributes
    command     = "rm -f kubeconfig-${self.name}"
    working_dir = "${path.module}/../../.."
    on_failure  = continue
  }

}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_node_pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${google_container_cluster.cluster.name}-node-pool"
  location = var.is_regional_cluster ? var.region:var.zone
  cluster    = google_container_cluster.cluster.id
  # NOT NEEDED initial_node_count = var.node_initial_node_count
  node_count = var.node_node_count
  version  = data.google_container_engine_versions.cluster_versions.latest_node_version

  node_config {
    disk_size_gb = var.node_disk_size_gb
    image_type = var.node_image_type
    oauth_scopes = var.node_oauth_scopes

    preemptible  = var.node_preemptible

    # use smaller for regional cluster that has more nodes
    machine_type = var.is_regional_cluster ? var.node_machine_type_regional:var.node_machine_type_zonal

    # network tags are for firewalls
    tags         = var.node_network_tags_list
    
    # kubernetes labels added to each node
    labels = {
      cluster = google_container_cluster.cluster.name
    }

    # do for all clusters
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

  # how many nodes can be created and lost during upgrades
  upgrade_settings {
    max_surge = var.nodes_max_surge
    max_unavailable = var.nodes_max_unavailable
  }

  # ignore these changes in nodepool
  lifecycle {
    ignore_changes = [
      initial_node_count,
      node_count,
      version
    ]
  }
#      node_count,

}

resource "google_compute_ssl_policy" "ssl-policy" {
  name            = "${var.cluster_name}-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

resource "google_compute_security_policy" "security-policy" {
  name = "${var.cluster_name}-security-policy"
  provider = google-beta

  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }

  rule {
    action   = "deny(403)"
    priority = "1000"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "XSS attack filtering"
  }
  rule {
    action   = "deny(403)"
    priority = "1001"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "SQL injection attack filtering"
  }
  rule {
    action   = "deny(403)"
    priority = "1002"
    match {
      expr {
        expression = "origin.region_code == 'RU'"
      }
    }
    description = "RU country block, test using www.locabrowser.com"
  }

  rule {
    action   = "allow"
    priority = "2147483647"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "default rule that must exist"
  }
}

# UNUSED!!!!
# Do not need anymore because internal HTTPS LB is using secret name just like external HTTPS LB
#
#resource "google_compute_ssl_certificate" "preshared-cert" {
#  name_prefix = "${var.cluster_name}-pre-shared-cert-int"
#  private_key = file("/tmp/my-secondary.${var.cluster_name}.local.key")
#  certificate = file("/tmp/my-secondary.${var.cluster_name}.local.crt")
#  lifecycle {
#    create_before_destroy = true
#  }
#}


# Register the cluster, makes viewable in 'Anthos' section
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/gke_hub_membership
# https://cloud.google.com/anthos/multicluster-management/connect/registering-a-cluster#register_cluster
#resource "google_gke_hub_membership" "membership" {
#  membership_id = google_container_cluster.cluster.name
#  endpoint {
#    gke_cluster {
#      resource_link = google_container_cluster.cluster.id
#    }
#  }
#  authority {
#    issuer = "https://container.googleapis.com/v1/${google_container_cluster.cluster.id}"
#  }
#}

