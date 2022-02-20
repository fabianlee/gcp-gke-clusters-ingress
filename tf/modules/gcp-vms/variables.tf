
variable vm_name {}
variable project {}
variable region {}
variable zone {}

variable vm_network {}
# use empty string if no subnet
variable vm_subnetwork { default="" }

variable os_image { default="ubuntu-os-cloud/ubuntu-2004-lts" }
variable machine_type { default="e2-small" }

# when preemptible is true, automatic restart MUST be false
variable scheduling_preemptible { default=true }
variable scheduling_automaticrestart { default=false }

variable has_public_ip { default=false }

variable vm_network_tags { 
  type = list(string)
  default = ["pubjumpbox"]
}

variable vm_scopes {
  type = list(string)
  default = ["cloud-platform"]
}

