
resource "null_resource" "gnegs" {
  for_each = { for i, v in local.new_gnegs : v.index_key => true }
}

# Global Network Endpoint Groups
resource "google_compute_global_network_endpoint_group" "default" {
  for_each              = { for i, v in local.new_gnegs : v.index_key => v }
  project               = each.value.project_id
  name                  = each.value.name
  network_endpoint_type = each.value.network_endpoint_type
  default_port          = each.value.default_port
  depends_on            = [null_resource.gnegs]
}

# Global Network Endpoints
resource "google_compute_global_network_endpoint" "default" {
  for_each                      = { for i, v in local.new_gnegs : v.endpoint_key => v }
  project                       = each.value.project_id
  global_network_endpoint_group = google_compute_global_network_endpoint_group.default[each.value.index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = google_compute_global_network_endpoint_group.default[each.value.index_key].default_port
}

resource "null_resource" "rnegs" {
  for_each = { for i, v in local.new_rnegs : v.index_key => true }
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
  depends_on = [null_resource.rnegs]
}

# Regional Network Endpoints
resource "google_compute_region_network_endpoint" "default" {
  for_each                      = { for i, v in local.new_rnegs : v.index_key => v if !v.is_psc }
  project                       = each.value.project_id
  region_network_endpoint_group = google_compute_region_network_endpoint_group.default[each.value.index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = each.value.port
  region                        = each.value.region
  depends_on                    = [null_resource.rnegs]
}

resource "null_resource" "znegs" {
  for_each = { for i, v in local.new_znegs : v.index_key => true }
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
  default_port          = each.value.default_port
  depends_on            = [null_resource.znegs]
}

# Zonal Network Endpoint
resource "google_compute_network_endpoint" "default" {
  for_each               = { for i, v in local.new_znegs : v.index_key => v }
  project                = each.value.project_id
  network_endpoint_group = google_compute_network_endpoint_group.default[each.value.index_key].id
  zone                   = each.value.zone
  instance               = each.value.instance
  ip_address             = each.value.ip_address
  port                   = google_compute_network_endpoint_group.default[each.value.index_key].default_port
  depends_on             = [null_resource.znegs]
}

