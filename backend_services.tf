# Backend Services
locals {
  _backend_services = local.backend_type != "bucket" ? [
    {
      create                  = local.create
      project_id              = local.project_id
      host_project_id         = local.host_project_id
      name                    = lower(trimspace(coalesce(local.name, "backend-service")))
      region                  = local.region
      groups                  = var.groups
      health_checks           = var.health_check != null ? [var.health_check] : coalesce(var.health_checks, [])
      session_affinity        = coalesce(var.session_affinity, "NONE")
      logging                 = coalesce(var.logging, false)
      timeout_sec             = coalesce(var.timeout, 30)
      protocol                = upper(trimspace(local.protocol))
      port                    = local.port
      port_name               = null
      uses_iap                = local.uses_iap
      is_application          = local.is_application
      is_classic              = local.is_classic
      is_regional             = local.is_regional
      is_internal             = local.is_internal
      negs                    = local.negs
      is_negs                 = length(local.negs) > 0 ? true : false
      is_rnegs                = local.is_negs && local.region != "global" ? true : false
      is_gneg                 = local.is_negs && local.region == "global" ? true : false
      security_policy         = var.security_policy
      iap                     = var.iap
      cdn                     = local.enable_cdn ? var.cdn : null
      custom_request_headers  = null
      custom_response_headers = null
    }
  ] : []
  __backend_services = [for i, v in local._backend_services :
    merge(v, {
      name        = var.name_prefix != null ? "${var.name_prefix}-${v.name}" : v.name
      description = trimspace(coalesce(local.description, "Backend Service '${v.name}'"))
      instance_groups = [for ig in coalesce(var.instance_groups, []) :
        {
          project_id = coalesce(ig.project_id, v.project_id)
          id         = ig.id
          name       = ig.name
          zone       = ig.zone
        }
      ]
      sample_rate = v.logging ? 1.0 : 0.0
    })
  ]
  ___backend_services = [for i, v in local.__backend_services :
    merge(v, {
      is_psc      = length([for neg in local.new_negs : neg if neg.is_psc]) > 0 ? true : false
      port        = try(coalesce(v.port, v.is_application ? (v.protocol == "HTTP" ? 80 : 443) : null), null)
      protocol    = coalesce(v.protocol, v.is_gneg ? "HTTPS" : "HTTP")
      enable_cdn  = v.is_application && !v.is_regional && !v.is_internal ? local.enable_cdn : false
      type        = local.type
      hc_prefix   = "${local.url_prefix}/${v.project_id}/${v.is_regional ? "regions/${v.region}" : "global"}/healthChecks"
      timeout_sec = v.is_rnegs ? null : v.timeout_sec
      instance_groups = length(local.groups) > 0 ? [] : [for ig in v.instance_groups :
        try(coalesce(
          ig.id,
          ig.zone != null && ig.name != null ? "projects/${ig.project_id}/zones/${ig.zone}/instanceGroups/${ig.name}" : null,
        ), [])
      ],
    })
  ]
  ____backend_services = flatten([for i, v in local.___backend_services :
    [v.is_application ? merge(v, {
      locality_lb_policy    = v.is_negs ? null : upper(coalesce(var.locality_lb_policy, "ROUND_ROBIN"))
      capacity_scaler       = v.is_rnegs ? null : coalesce(var.capacity_scaler, 1.0)
      max_utilization       = v.is_rnegs ? null : coalesce(var.max_utilization, 0.8)
      max_rate_per_instance = var.max_rate_per_instance
      }) : merge(v, {
      locality_lb_policy    = null
      capacity_scaler       = null
      max_utilization       = null
      max_rate_per_instance = null
    })]
  ])
  backend_services = [for i, v in local.____backend_services :
    merge(v, {
      load_balancing_scheme           = local.is_application && !local.is_classic ? "${local.type}_MANAGED" : local.type
      security_policy                 = local.is_application ? var.security_policy : null
      network                         = local.is_application && v.is_regional && !v.is_internal ? local.network : null
      subnet                          = local.is_application && v.is_regional && !v.is_internal ? local.subnet : null
      balancing_mode                  = local.protocol == "TCP" ? "CONNECTION" : v.is_negs ? null : "UTILIZATION"
      connection_draining_timeout_sec = coalesce(var.connection_draining_timeout, 300)
      max_connections                 = v.protocol == "TCP" && !v.is_regional ? coalesce(v.max_connections, 8192) : null
      groups = try(coalescelist(v.groups, v.instance_groups,
        [for neg in local.new_gnegs : "projects/${neg.project_id}/global/networkEndpointGroups/${neg.name}" if neg.backend_name == v.name],
        [for neg in local.new_rnegs : "projects/${neg.project_id}/regions/${neg.region}/networkEndpointGroups/${neg.name}" if neg.backend_name == v.name],
      ), []) # This will result in 'has no backends configured' which is easier to troubleshoot than an ugly error
      health_checks = v.is_negs ? null : flatten([for health_check in v.health_checks :
        [startswith(health_check, local.url_prefix) ? health_check : "${v.hc_prefix}/${health_check}"]
      ])
      cdn_cache_mode  = v.enable_cdn ? upper(coalesce(v.cdn.cache_mode, "CACHE_ALL_STATIC")) : null
      cdn_default_ttl = v.enable_cdn ? 3600 : null
      cdn_min_ttl     = v.enable_cdn ? 60 : null
      cdn_max_ttl     = v.enable_cdn ? 14400 : null
      cdn_client_ttl  = v.enable_cdn ? 3600 : null
      index_key       = v.is_regional ? "${v.project_id}/${v.region}/${v.name}" : "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
}

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
  ]
}
