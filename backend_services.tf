
# Generate a null resource for each Backend key, so existing one is completely destroyed before attempting re-create
resource "null_resource" "backend_services" {
  for_each = { for i, v in local.backend_services : v.index_key => true }
}

# Global Backend Service
resource "google_compute_backend_service" "default" {
  for_each                        = { for i, v in local.backend_services : v.index_key => v if !v.is_regional }
  project                         = each.value.project_id
  name                            = each.value.name
  description                     = each.value.description
  load_balancing_scheme           = each.value.load_balancing_scheme
  locality_lb_policy              = each.value.locality_lb_policy
  protocol                        = each.value.protocol
  port_name                       = each.value.port_name
  timeout_sec                     = each.value.timeout_sec
  health_checks                   = each.value.health_checks
  session_affinity                = each.value.session_affinity
  connection_draining_timeout_sec = each.value.connection_draining_timeout_sec
  custom_request_headers          = each.value.custom_request_headers
  custom_response_headers         = each.value.custom_response_headers
  security_policy                 = each.value.security_policy
  dynamic "backend" {
    for_each = each.value.groups
    content {
      group                 = backend.value
      capacity_scaler       = each.value.capacity_scaler
      balancing_mode        = each.value.balancing_mode
      max_rate_per_instance = each.value.max_rate_per_instance
      max_rate_per_endpoint = each.value.max_rate_per_endpoint
      max_utilization       = each.value.max_utilization
      max_connections       = each.value.max_connections
    }
  }
  dynamic "log_config" {
    for_each = each.value.logging ? [true] : []
    content {
      enable      = true
      sample_rate = each.value.sample_rate
    }
  }
  dynamic "consistent_hash" {
    for_each = each.value.locality_lb_policy == "RING_HASH" ? [true] : []
    content {
      minimum_ring_size = 1
    }
  }
  dynamic "iap" {
    for_each = each.value.uses_iap ? [true] : []
    content {
      oauth2_client_id     = google_iap_client.default[each.key].client_id
      oauth2_client_secret = google_iap_client.default[each.key].secret
    }
  }
  enable_cdn = each.value.enable_cdn
  dynamic "cdn_policy" {
    for_each = each.value.enable_cdn == true ? [true] : []
    content {
      cache_mode                   = each.value.cdn_cache_mode
      signed_url_cache_max_age_sec = 3600
      default_ttl                  = each.value.cdn_default_ttl
      client_ttl                   = each.value.cdn_client_ttl
      max_ttl                      = each.value.cdn_max_ttl
      negative_caching             = false
      cache_key_policy {
        include_host           = true
        include_protocol       = true
        include_query_string   = true
        query_string_blacklist = []
        query_string_whitelist = []
      }
    }
  }
  depends_on = [
    null_resource.backend_services,
    google_compute_region_network_endpoint_group.default,
    google_compute_global_network_endpoint_group.default,
    google_compute_network_endpoint_group.default,
  ]
}

# Regional Backend Service
resource "google_compute_region_backend_service" "default" {
  for_each                        = { for i, v in local.backend_services : v.index_key => v if v.is_regional }
  project                         = each.value.project_id
  name                            = each.value.name
  description                     = each.value.description
  load_balancing_scheme           = each.value.load_balancing_scheme
  locality_lb_policy              = each.value.locality_lb_policy
  protocol                        = each.value.protocol
  port_name                       = each.value.port_name
  timeout_sec                     = each.value.timeout_sec
  health_checks                   = each.value.health_checks
  session_affinity                = each.value.session_affinity
  connection_draining_timeout_sec = each.value.connection_draining_timeout_sec
  dynamic "backend" {
    for_each = each.value.groups
    content {
      group                 = backend.value
      capacity_scaler       = each.value.capacity_scaler
      balancing_mode        = each.value.balancing_mode
      max_rate_per_instance = each.value.max_rate_per_instance
      max_rate_per_endpoint = each.value.max_rate_per_endpoint
      max_utilization       = each.value.max_utilization
      max_connections       = each.value.max_connections
    }
  }
  dynamic "log_config" {
    for_each = each.value.logging ? [true] : []
    content {
      enable      = true
      sample_rate = each.value.sample_rate
    }
  }
  dynamic "consistent_hash" {
    for_each = each.value.locality_lb_policy == "RING_HASH" ? [true] : []
    content {
      minimum_ring_size = 1
    }
  }
  region = each.value.region
  depends_on = [
    null_resource.backend_services,
    google_compute_region_network_endpoint_group.default,
    google_compute_global_network_endpoint_group.default,
    google_compute_network_endpoint_group.default,
  ]
}
