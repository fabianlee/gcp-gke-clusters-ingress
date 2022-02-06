
resource "google_compute_instance" "wgserver" {
  name         = "gcp-ubuntu-pub-wg"
  machine_type = var.machine_type
  zone         = var.zone
  can_ip_forward = true

  #depends_on = [google_compute_network.wg_network]
  depends_on = [google_compute_subnetwork.wg_subnetwork]

  boot_disk {
    initialize_params {
      image = var.os_image
      type = "pd-ssd"
      size = "40"
    }
  }

  network_interface {
    network = "wg-network"
    subnetwork = "wg-subnetwork"
    network_ip = cidrhost(var.cidr_block,10)

    access_config {
      // empty block means ephemeral external IP
    }
  }


  // using ssh key attached directly to vm (not ssh key in project level metadata)  
  metadata = {
    ssh-keys = "ubuntu:${file("../ansible_rsa.pub")}"
  }

  // https://medium.com/slalom-technology/a-complete-gcp-environment-with-terraform-c087190366f0
  // https://stackoverflow.com/questions/57682483/terraform-gcp-startup-script-local-file-instead-of-inline
#  metadata_startup_script = <<SCRIPT
#    sudo apt-get update && sudo apt-get install apache2 -y
#    export HOSTNAME=$(hostname | tr -d '\n')
#    export PRIVATE_IP=$(curl -sf -H 'Metadata-Flavor:Google' http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip | tr -d '\n')
#    echo "<html><body><h1>Hello, World! From $HOSTNAME at $PRIVATE_IP</h1></body></html>" | sudo tee /var/www/html/index.html
#    SCRIPT


  # https://alex.dzyoba.com/blog/terraform-ansible/
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update --allow-unauthenticated -q"
    ]
    connection {
      type = "ssh"
      #timeout = 200
      user = "ubuntu"
      host = self.network_interface.0.access_config.0.nat_ip
      private_key = file("${path.module}/../ansible_rsa")
    }
  }

  service_account {
    # leaving empty means default compute engine service account will be used
    #email = ""
    scopes = ["cloud-platform"]
  }


  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["wg-server"]
}

# all private wireguard traffic goes to public wireguard instance for forwarding
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_route
resource "google_compute_route" "other_route" {
  depends_on = [google_compute_instance.wgserver]

  name        = "route-wg-network-to-public-instance"
  dest_range  = var.wireguard_cidr
  network     = google_compute_network.wg_network.name
  next_hop_instance = google_compute_instance.wgserver.self_link
  priority    = 100
}
# all traffic to other VPC goes to public wireguard instance for forwarding
resource "google_compute_route" "other_vpc_route" {
  depends_on = [google_compute_instance.wgserver]

  name        = "route-other-vpc-to-public-instance"
  dest_range  = var.other_vpc_cidr
  network     = google_compute_network.wg_network.name
  next_hop_instance = google_compute_instance.wgserver.self_link
  priority    = 200
}

data "template_file" "default" {
  template = file("${path.module}/startup.sh")
  vars = {
    foo = "bar"
  }
}

resource "google_compute_instance" "web" {
  name         = "gcp-ubuntu-priv-web"
  machine_type = var.machine_type
  zone         = var.zone
  can_ip_forward = true

  #depends_on = [google_compute_network.wg_network]
  depends_on = [google_compute_subnetwork.wg_subnetwork]

  boot_disk {
    initialize_params {
      image = var.os_image
      type = "pd-ssd"
      size = "40"
    }
  }

  network_interface {
    network = "wg-network"
    subnetwork = "private-subnetwork"
    network_ip = cidrhost(var.private_cidr_block,129)

    // no public IP wanted
    //access_config {
      // empty block means ephemeral external IP
    //}
  }


  // using ssh key attached directly to vm (not ssh key in project level metadata)  
  metadata = {
    ssh-keys = "ubuntu:${file("../ansible_rsa.pub")}"
  }

  // coming from template
  //metadata_startup_script = data.template_file.default.rendered

  // direct from file
  //metadata_startup_script = file("${path.module}/startup.sh")  

  // inline
  // https://medium.com/slalom-technology/a-complete-gcp-environment-with-terraform-c087190366f0
#  metadata_startup_script = <<SCRIPT
#    sudo apt-get update && sudo apt-get install apache2 -y
#    export HOSTNAME=$(hostname | tr -d '\n')
#    export PRIVATE_IP=$(curl -sf -H 'Metadata-Flavor:Google' http://metadata/computeMetadata/v1/instance/network-interfaces/0/ip | tr -d '\n')
#    echo "<html><body><h1>Hello, World! From $HOSTNAME at $PRIVATE_IP</h1></body></html>" | sudo tee /var/www/html/index.html
#    SCRIPT

  // Apply the firewall rule to allow external IPs to access this instance
  tags = ["web-server"]
}


