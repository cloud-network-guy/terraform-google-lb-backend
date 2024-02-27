/*
locals {
  _new_rnegs = flatten([for backend_service in local.__backend_services :
    [for i, rneg in coalesce(backend_service.rnegs, []) :
      {
        project_id         = coalesce(lookup(rneg, "project_id", null), backend_service.project_id)
        host_project_id    = backend_service.host_project_id
        name               = coalesce(lookup(rneg, "name", null), "rneg-${backend_service.name}-${i}")
        backend_name       = backend_service.name
        region             = coalesce(rneg.region, backend_service.region, local.region)
        network            = coalesce(rneg.network, local.network)
        subnet             = coalesce(rneg.subnet, local.subnet)
        is_cloud_run       = lookup(rneg, "cloud_run_service", null) != null ? true : false
        cloud_run_service  = lookup(rneg, "cloud_run_service", null)
        is_psc             = lookup(rneg, "psc_target", null) != null ? true : false
        psc_target_service = lookup(rneg, "psc_target", null)
      }
    ]
  ])
  new_rnegs = [for i, v in local._new_rnegs :
    merge(v, {
      network_endpoint_type = v.is_psc ? "PRIVATE_SERVICE_CONNECT" : "SERVERLESS"
      cloud_run_service     = v.is_cloud_run ? v.cloud_run_service : null
      psc_target_service    = v.is_psc ? v.psc_target_service : null
      network               = v.is_psc ? "projects/${v.host_project_id}/global/networks/${v.network}" : null
      subnetwork            = v.is_psc ? "projects/${v.host_project_id}/regions/${v.region}/subnetworks/${v.subnet}" : null
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
    for_each = each.value.is_cloud_run ? [true] : []
    content {
      service = each.value.cloud_run_service
    }
  }
}

# Regional Network Endpoints
resource "google_compute_region_network_endpoint" "default" {
  for_each                      = { for i, v in local.new_rnegs : v.index_key => v }
  project                       = each.value.project_id
  region_network_endpoint_group = google_compute_region_network_endpoint_group.default[each.value.index_key].id
  fqdn                          = each.value.fqdn
  ip_address                    = each.value.ip_address
  port                          = each.value.port
  region                        = each.value.region
}
*/