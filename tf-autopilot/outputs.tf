
output "gcp-ubuntu-pub-wg_public_ip" {
  value = google_compute_instance.wgserver.network_interface.0.access_config.0.nat_ip
}
output "gcp-ubuntu-pub-wg_private_ip" {
  value = google_compute_instance.wgserver.network_interface.0.network_ip
}

# access_config will not exist because web has no public IP
#output "gcp-ubuntu-priv-web-public_ip" {
#  value = google_compute_instance.web.network_interface.0.access_config.0.nat_ip
#}
output "gcp-ubuntu-priv-web-private_ip" {
  value = google_compute_instance.web.network_interface.0.network_ip
}

#output "gcp-nat_ip_address" {
#  value = google_compute_address.nat-ip.address
#}

