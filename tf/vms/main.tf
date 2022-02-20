

module "gcp-vms" {
  source = "../modules/gcp-vms"
  for_each = var.vms

  vm_name    = "vm-${each.key}"
  project    = var.project
  region     = var.region
  zone       = var.zone
  vm_network = var.vpc_network_name

  vm_subnetwork   = each.key
  has_public_ip   = each.value.is_public
  vm_scopes       = each.value.scopes
  vm_network_tags = each.value.tags
}


# if object: terraform output -json <varname> | jq
# if value:  terraform output -raw <varname>
output "module_internal_ip" {
  value = zipmap(
    keys(module.gcp-vms),
    values(module.gcp-vms)[*].internal_ip
  )
}
output "module_public_ip" {
  value = zipmap(
    keys(module.gcp-vms),
    values(module.gcp-vms)[*].public_ip
  )
}
