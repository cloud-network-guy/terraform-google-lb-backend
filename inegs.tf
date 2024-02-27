/*
locals {
  # From backends, create a list of objects containing only Internet Network Endpoint Groups
  _new_inegs = flatten([for i, v in local.__backend_services :
    {
      create       = true
      project_id   = v.project_id
      backend_name = v.name
      name         = v.ineg.name
      fqdn         = v.ineg.fqdn
      ip_address   = v.ineg.ip_address
      port         = coalesce(v.ineg.port, 443) # Default to HTTPS since this via Internet
    } if v.is_ineg == true
  ])
  __new_inegs = [for i, v in local._new_inegs :
    merge(v, {
      default_port          = v.port
      name                  = coalesce(v.name, "ineg-${v.backend_name}-${v.port}")
      network_endpoint_type = v.fqdn != null ? "INTERNET_FQDN_PORT" : "INTERNET_IP_PORT"
    })
  ]
  new_inegs = [for i, v in local.__new_inegs :
    merge(v, {
      index_key = "${v.project_id}/${v.name}"
    }) if v.create == true
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
*/