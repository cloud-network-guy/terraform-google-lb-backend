locals {
  url_prefix      = "https://www.googleapis.com/compute/v1/projects"
  create          = coalesce(var.create, true)
  project_id      = var.project_id
  host_project_id = coalesce(var.host_project_id, local.project_id)
  name_prefix     = var.name_prefix != null ? lower(trimspace(var.name_prefix)) : null
  name            = var.name != null ? lower(trimspace(var.name)) : null
  description     = coalesce(var.description, "Managed by Terraform")
  is_regional     = var.region != null ? true : false
  region          = local.is_regional ? var.region : "global"
  port            = coalesce(var.port, 80)
  protocol        = var.protocol != null ? upper(var.protocol) : "HTTP"
  is_application  = startswith(local.protocol, "HTTP") ? true : false
  network         = coalesce(var.network, "default")
  subnet          = coalesce(var.subnet, "default")
  is_internal     = var.subnet != null ? true : false
  type            = local.is_internal ? "INTERNAL" : "EXTERNAL"
  is_classic      = coalesce(var.classic, false)
  is_bucket       = var.bucket != null ? true : false
  negs            = coalesce(var.negs, [])
  is_negs         = length(local.negs) > 0 ? true : false
  uses_iap        = var.iap != null ? true : false
  enable_cdn      = var.cdn != null ? true : false
  backend_type    = var.bucket != null ? "bucket" : "service"
  groups          = coalesce(var.groups, [])
  #labels                 = { for k, v in coalesce(var.labels, {}) : k => lower(replace(v, " ", "_")) }
}
