output "cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "GKE standard Cluster Name"
}
