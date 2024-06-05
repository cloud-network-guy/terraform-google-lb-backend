
locals {
  url_prefix      = "https://www.googleapis.com/compute/v1"
  create          = coalesce(var.create, true)
  project_id      = lower(trimspace(var.project_id))
  host_project_id = lower(trimspace(coalesce(var.host_project_id, local.project_id)))
  name_prefix     = var.name_prefix != null ? lower(trimspace(var.name_prefix)) : null
  name            = var.name != null ? lower(trimspace(var.name)) : null
  description     = coalesce(var.description, "Managed by Terraform")
  is_regional     = var.region != null && var.region != "global" ? true : false
  region          = local.is_regional ? var.region : "global"
  port            = var.port
  protocol        = var.protocol != null ? upper(var.protocol) : "TCP"
  is_application  = startswith(local.protocol, "HTTP") || local.is_negs ? true : false
  network         = coalesce(var.network, "default")
  subnet          = coalesce(var.subnet, "default")
  is_internal     = local.type == "INTERNAL" ? true : false
  type            = upper(coalesce(var.type != null ? var.type : "EXTERNAL"))
  is_classic      = coalesce(var.classic, false)
  groups          = coalesce(var.groups, [])
  is_igs          = length([for _ in local.groups : _ if strcontains(_, "/instanceGroups/")]) > 0 ? true : false
  is_negs         = length([for _ in local.groups : _ if strcontains(_, "/networkEndpointGroups/")]) > 0 ? true : false
  is_gnegs        = length([for _ in local.groups : _ if local.is_negs && strcontains(_, "/global/")]) > 0 ? true : false
  is_rnegs        = length([for _ in local.groups : _ if local.is_negs && strcontains(_, "/regions/")]) > 0 ? true : false
  is_znegs        = length([for _ in local.groups : _ if local.is_negs && strcontains(_, "/zones/")]) > 0 ? true : false
  bucket          = var.bucket != null && local.is_application && !local.is_regional && !local.is_internal ? var.bucket : null
  is_bucket       = local.bucket != null ? true : false
  create_bucket   = local.bucket != null ? lookup(local.bucket, "create", false) : false
  is_service      = !local.is_bucket ? true : false
  iap             = var.iap != null && local.is_application && !local.is_regional && !local.is_internal ? var.iap : null
  uses_iap        = local.iap != null && local.is_service ? true : false
  cdn             = var.cdn != null && local.is_application && !local.is_regional && !local.is_internal ? var.cdn : null
  enable_cdn      = local.cdn != null ? true : false
  health_checks   = var.health_check != null ? [var.health_check] : coalesce(var.health_checks, [])
  is_psc          = false
  #labels                 = { for k, v in coalesce(var.labels, {}) : k => lower(replace(v, " ", "_")) }
  _backend_services = local.is_service ? [
    {
      create                  = local.create
      project_id              = local.project_id
      name                    = lower(trimspace(coalesce(local.name, "backend-service")))
      health_checks           = local.health_checks
      session_affinity        = upper(trimspace(coalesce(var.session_affinity, "NONE")))
      logging                 = coalesce(var.logging, false)
      timeout_sec             = coalesce(var.timeout, 30)
      protocol                = upper(trimspace(local.protocol))
      port                    = local.port
      uses_iap                = local.uses_iap
      region                  = local.is_regional ? local.region : null
      enable_cdn              = local.enable_cdn
      security_policy         = var.security_policy
      iap                     = var.iap
      custom_request_headers  = null
      custom_response_headers = null
    }
  ] : []
  __backend_services = [for i, v in local._backend_services :
    merge(v, {
      name        = var.name_prefix != null ? "${var.name_prefix}-${v.name}" : v.name
      description = trimspace(coalesce(local.description, "Backend Service '${v.name}'"))
      sample_rate = v.logging ? 1.0 : 0.0
      port        = try(coalesce(v.port, local.is_application ? (v.protocol == "HTTP" ? 80 : 443) : null), null)
    })
  ]
  backend_services = [for i, v in local.__backend_services :
    merge(v, {
      hc_prefix                       = "${local.url_prefix}/projects/${local.project_id}/${local.is_regional ? "regions/${v.region}" : "global"}/healthChecks"
      groups                          = [for group in local.groups : (startswith(group, local.url_prefix) ? group : "${local.url_prefix}/${group}")]
      port                            = local.is_application ? null : coalesce(v.port, local.is_gnegs ? 443 : 80)
      port_name                       = local.is_application && local.is_igs ? v.port_name : null
      protocol                        = local.is_gnegs ? "HTTPS" : v.protocol # Assume HTTPS since global NEGs go via Internet
      timeout_sec                     = local.is_rnegs ? null : v.timeout_sec
      load_balancing_scheme           = local.is_application && !local.is_classic ? "${local.type}_MANAGED" : local.type
      locality_lb_policy              = local.is_application && !local.is_classic && !local.is_gnegs ? upper(coalesce(var.locality_lb_policy, "ROUND_ROBIN")) : null
      security_policy                 = local.is_application ? var.security_policy : null
      network                         = local.is_application && local.is_regional && !local.is_internal ? local.network : null
      subnet                          = local.is_application && local.is_regional && !local.is_internal ? local.subnet : null
      balancing_mode                  = !local.is_application ? "CONNECTION" : local.is_gnegs ? null : local.is_negs ? "RATE" : "UTILIZATION"
      max_rate_per_instance           = local.is_application && local.is_igs ? coalesce(var.max_rate_per_instance, 1024) : null
      max_rate_per_endpoint           = local.is_application && local.is_negs && !local.is_gnegs ? 42 : null
      connection_draining_timeout_sec = coalesce(var.connection_draining_timeout, 300)
      max_connections                 = v.protocol == "TCP" && !local.is_regional && !local.is_gnegs ? coalesce(var.max_connections, 8192) : null
      capacity_scaler                 = local.is_application ? coalesce(var.capacity_scaler, 1.0) : null
      max_utilization                 = local.is_application ? coalesce(var.max_utilization, 0.8) : null
      cdn_cache_mode                  = local.enable_cdn ? upper(coalesce(lookup(v.cdn, "cache_mode", null), "CACHE_ALL_STATIC")) : null
      health_checks = local.is_gnegs || local.is_psc ? null : flatten([for _ in v.health_checks :
        [
          startswith(_, local.url_prefix) ? _ :
          startswith(_, "projects/") ? "${local.url_prefix}/${_}" : "${v.hc_prefix}/${_}"
        ]
      ])
      cdn_cache_mode  = local.enable_cdn ? v.cdn_cache_mode : null
      cdn_default_ttl = local.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 3600 : 0) : null
      cdn_min_ttl     = local.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 60 : 0) : null
      cdn_max_ttl     = local.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 14400 : 0) : null
      cdn_client_ttl  = local.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 3600 : 0) : null
      index_key       = local.is_regional ? "${v.project_id}/${v.region}/${v.name}" : "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
  _iaps = [for i, v in local.backend_services :
    {
      create              = lookup(v.iap, "create", local.create)
      project_id          = local.project_id
      name                = lookup(v.iap, "name", "iap-${v.name}")
      application_title   = lookup(v.iap, "application_title", coalesce(v.description, v.name))
      support_email       = v.iap.support_email
      display_name        = v.name
      web_backend_service = v.name
      role                = "roles/iap.httpsResourceAccessor"
      members             = toset(coalesce(v.iap.members, []))
    } if v.uses_iap == true
  ]
  iaps = [for i, v in local._iaps :
    merge(v, {
      index_key = "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
}

# IAP Brand
resource "google_iap_brand" "default" {
  for_each          = { for i, v in local.iaps : v.index_key => v }
  project           = each.value.project_id
  application_title = each.value.application_title
  support_email     = each.value.support_email
}

# IAP Client
resource "google_iap_client" "default" {
  for_each     = { for i, v in local.iaps : v.index_key => v }
  display_name = each.value.display_name
  brand        = google_iap_brand.default[each.value.index_key].name
}

# IAP IAM Binding
resource "google_iap_web_backend_service_iam_binding" "default" {
  for_each            = { for i, v in local.iaps : v.index_key => v }
  project             = each.value.project_id
  web_backend_service = each.value.web_backend_service
  role                = each.value.role
  members             = each.value.members
}

# Generate a null resource for each Backend key, so existing one is completely destroyed before attempting re-create
resource "null_resource" "backend_services" {
  for_each = { for i, v in local.backend_services : v.index_key => true }
}

# Global Backend Service
resource "google_compute_backend_service" "default" {
  for_each                        = { for i, v in local.backend_services : v.index_key => v if !local.is_regional }
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
  depends_on = [null_resource.backend_services]
}

# Regional Backend Service
resource "google_compute_region_backend_service" "default" {
  for_each                        = { for i, v in local.backend_services : v.index_key => v if local.is_regional }
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
  region     = each.value.region
  depends_on = [null_resource.backend_services]
}

# GCS Bucket
locals {
  _gcs_buckets = local.is_bucket && local.create_bucket ? [
    {
      create                      = coalesce(lookup(var.bucket, "create", null), false)
      project_id                  = local.project_id
      name                        = lookup(var.bucket, "name", local.name)
      location                    = lookup(var.bucket, "location", "US")
      uniform_bucket_level_access = true
      force_destroy               = lookup(var.bucket, "force_destroy", true)
    }
  ] : []
  gcs_buckets = [for i, v in local._gcs_buckets :
    merge(v, {
      index_key = "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
}
resource "google_storage_bucket" "default" {
  for_each                    = { for i, v in local.gcs_buckets : v.index_key => v }
  project                     = each.value.project_id
  name                        = each.value.name
  location                    = each.value.location
  uniform_bucket_level_access = each.value.uniform_bucket_level_access
  force_destroy               = each.value.force_destroy
}

# Backend Bucket
locals {
  _backend_buckets = local.is_bucket ? [
    {
      project_id  = local.project_id
      name        = local.name
      bucket_name = local.bucket != null ? lookup(local.bucket, "name", local.name) : local.name
      enable_cdn  = local.enable_cdn
    }
  ] : []
  backend_buckets = [for i, v in local._backend_buckets :
    merge(v, {
      description = coalesce(local.description, "Backend to GCS Bucket '${v.bucket_name}'")
      index_key   = "${v.project_id}/${v.name}"
    })
  ]
}
resource "google_compute_backend_bucket" "default" {
  for_each    = { for i, v in local.backend_buckets : v.index_key => v }
  project     = each.value.project_id
  name        = each.value.name
  bucket_name = each.value.bucket_name
  description = each.value.description
  enable_cdn  = each.value.enable_cdn
}
