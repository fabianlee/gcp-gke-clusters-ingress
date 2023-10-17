variable project {}
variable region {}
variable zone {}

variable vpc_network_name {}

variable "vms" {
  type = map
  default = {
  "pub-10-0-90-0" = { is_public=true, scopes=[], tags=["pubjumpbox"], additional_metadata={gl_executor="docker"} },
  "pub-10-0-91-0" = { is_public=true, scopes=[], tags=["pubjumpbox"], additional_metadata={gl_executor="docker"} },
  "prv-10-0-100-0" = { is_public=false, scopes=[], tags=[], additional_metadata={gl_executor="docker"} },
  "prv-10-0-101-0" = { is_public=false, scopes=[], tags=[], additional_metadata={gl_executor="docker"} }
  }
}

