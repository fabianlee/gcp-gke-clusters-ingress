variable project {}
variable region {}
variable zone {}
variable cidr_block {}
variable private_cidr_block { }
variable os_image { default="ubuntu-os-cloud/ubuntu-2004-lts" }
variable machine_type { default="f1-micro" }

variable multi_region_location {}

variable other_vpc_cidr {}
variable wireguard_cidr { default="10.0.14.0/24" }

