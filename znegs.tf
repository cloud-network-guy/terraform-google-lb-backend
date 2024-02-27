/*
locals {
  _new_znegs = flatten([for backend_service in local.__backend_services :
    [for i, zneg in coalesce(backend_service.znegs, []) :
      {
        project_id            = coalesce(lookup(zneg, "project_id", null), backend_service.project_id)
        host_project_id       = backend_service.host_project_id
        name                  = coalesce(lookup(zneg, "name", null), "zneg-${backend_service.name}-${i}")
        zone                  = zneg.zone
        network               = coalesce(zneg.network, local.network)
        subnet                = coalesce(zneg.subnet, local.subnet)
        network_endpoint_type = coalesce(zneg.type, "GCE_VM_IP_PORT")
        ip_address            = lookup(zneg, "ip_address", null)
        instance              = lookup(zneg, "instance", null)
      }
    ]
  ])
  new_znegs = [for i, v in local.new_negs :
    merge(v, {
      network    = startswith(v.network, "projects/") ? v.network : "projects/${v.host_project_id}/global/networks/${v.network}"
      subnetwork = startswith(v.subnet, "projects/") ? v.subnet : "projects/${v.host_project_id}/regions/${v.region}/subnetworks/${v.subnet}"
      index_key  = "${v.project_id}/${v.zone}/${v.name}"
    }) if v.type == "zonal"
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

# Network Endpoint
resource "google_compute_network_endpoint" "default" {
  for_each               = { for i, v in local.new_znegs : v.index_key => v if v.instance != null }
  project                = each.value.project_id
  network_endpoint_group = google_compute_network_endpoint_group.default[each.value.index_key].id
  instance               = each.value.instance
  port                   = each.value.port
  ip_address             = each.value.ip_address
}
*/