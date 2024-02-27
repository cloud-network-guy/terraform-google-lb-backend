locals {
  _new_negs = flatten([
    for backend_service in local.__backend_services :
    [
      for i, neg in backend_service.negs :
      {
        project_id      = backend_service.project_id
        host_project_id = backend_service.host_project_id
        name            = lookup(neg, "name", null)
        region          = try(coalesce(lookup(neg, "region", null), backend_service.region, local.region), null)
        zone            = lookup(neg, "zone", null)
        network         = lookup(neg, "network", null)
        subnet          = lookup(neg, "subnet", null)
        fqdn            = lookup(neg, "fqdn", null)
        ip_address      = lookup(neg, "ip_address", null)
        port            = lookup(neg, "port", null)
        psc_target      = lookup(neg, "psc_target", null)
        backend_name    = backend_service.name
      }
    ] if backend_service.create == true
  ])
  __new_negs = [
    for i, v in local._new_negs :
    merge(v, {
      name    = "${local.name_prefix != null ? "${local.name_prefix}-" : ""}${coalesce(v.name, "neg-${v.backend_name}-${i}")}"
      network = coalesce(v.network, local.network)
      subnet  = coalesce(v.subnet, local.subnet)
      region  = v.zone != null ? null : coalesce(v.region, "global")
      is_psc  = v.psc_target != null ? true : false
    })
  ]
  new_negs = [
    for i, v in local.__new_negs :
    merge(v, {
      network    = startswith(v.network, "projects/") ? v.network : "projects/${v.host_project_id}/global/networks/${v.network}"
      subnetwork = startswith(v.subnet, "projects/") ? v.subnet : "projects/${v.host_project_id}/regions/${v.region}/subnetworks/${v.subnet}"
    })
  ]
}

# Prep local for Global Network Endpoint Groups
locals {
  _new_gnegs = [
    for i, v in local.new_negs :
    merge(v, {
      port         = coalesce(v.port, 443) # Going via Internet, so assume we want HTTPS
      default_port = coalesce(v.port, 443)
      network      = null
      subnetwork   = null
    }) if v.region == "global" && !v.is_psc
  ]
  new_gnegs = [
    for i, v in local._new_gnegs :
    merge(v, {
      network_endpoint_type = v.fqdn != null ? "INTERNET_FQDN_PORT" : "INTERNET_IP_PORT"
      index_key             = "${v.project_id}/${v.name}"
    })
  ]
}

# Global Network Endpoint Groups
resource "google_compute_global_network_endpoint_group" "default" {
  for_each              = { for i, v in local.new_gnegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  default_port          = each.value.default_port
}

# Global Network Endpoints
resource "google_compute_global_network_endpoint" "default" {
  for_each                      = { for i, v in local.new_gnegs : v.index_key => v }
  project                       = each.value.project_id
  global_network_endpoint_group = google_compute_global_network_endpoint_group.default[each.value.index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = each.value.port
}

# Prep local for Regional Network Endpoint Groups
locals {
  _new_rnegs = [
    for i, v in local.new_negs :
    merge(v, {
      port               = coalesce(v.port, 80)
      cloud_run_service  = lookup(v, "cloud_run_service", null)
      psc_target_service = v.psc_target
      region             = v.region
    }) if v.region != null && v.region != "global" || v.is_psc
  ]
  __new_rnegs = [
    for i, v in local._new_rnegs :
    merge(v, {
      is_serverless = v.cloud_run_service != null ? true : false
    })
  ]
  new_rnegs = [
    for i, v in local.__new_rnegs :
    merge(v, {
      network_endpoint_type = v.is_psc ? "PRIVATE_SERVICE_CONNECT" : v.fqdn != null ? "INTERNET_FQDN_PORT" : "INTERNET_IP_PORT"
      cloud_run_service     = v.is_serverless ? v.cloud_run_service : null
      psc_target_service    = v.is_psc ? v.psc_target_service : null
      network               = v.is_serverless ? null : v.network
      subnetwork            = v.is_psc ? v.subnetwork : null
      index_key             = "${v.project_id}/${v.region}/${v.name}"
    })
  ]
}

# Regional Network Endpoint Group
resource "google_compute_region_network_endpoint_group" "default" {
  for_each              = { for i, v in local.new_rnegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  region                = each.value.region
  psc_target_service    = each.value.psc_target_service
  network               = each.value.network
  subnetwork            = each.value.subnetwork
  dynamic "cloud_run" {
    for_each = each.value.cloud_run_service != null ? [true] : []
    content {
      service = each.value.cloud_run_service
    }
  }
}

# Regional Network Endpoints
resource "google_compute_region_network_endpoint" "default" {
  for_each                      = { for i, v in local.new_rnegs : v.index_key => v if !v.is_psc}
  project                       = each.value.project_id
  region_network_endpoint_group = google_compute_region_network_endpoint_group.default[each.value.index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = each.value.port
  region                        = each.value.region
}

# Prep local for Zonal Network Endpoint Groups
locals {
  new_znegs = [
    for i, v in local.new_negs :
    merge(v, {
      instance  = lookup(v, "instance", null)
      index_key = "${v.project_id}/${v.zone}/${v.name}"
    }) if v.zone != null
  ]
}

# Zonal Network Endpoint Group
resource "google_compute_network_endpoint_group" "default" {
  for_each              = { for i, v in local.new_znegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  zone                  = each.value.zone
  network               = each.value.network
  subnetwork            = each.value.subnetwork
}

# Zonal Network Endpoint
resource "google_compute_network_endpoint" "default" {
  for_each               = { for i, v in local.new_znegs : v.index_key => v if v.instance != null }
  project                = each.value.project_id
  network_endpoint_group = google_compute_network_endpoint_group.default[each.value.index_key].id
  instance               = each.value.instance
  ip_address             = each.value.ip_address
  port                   = each.value.port
}