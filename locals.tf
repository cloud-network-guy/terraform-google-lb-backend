locals {
  url_prefix      = "https://www.googleapis.com/compute/v1"
  create          = coalesce(var.create, true)
  project_id      = var.project_id
  host_project_id = coalesce(var.host_project_id, local.project_id)
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
  is_bucket       = var.bucket != null ? true : false
  negs            = coalesce(var.negs, [])
  is_negs         = length(local.negs) > 0 ? true : false
  uses_iap        = var.iap != null ? true : false
  enable_cdn      = var.cdn != null ? true : false
  backend_type    = var.bucket != null ? "bucket" : "service"
  groups          = coalesce(var.groups, [])
  health_checks   = var.health_check != null ? [var.health_check] : coalesce(var.health_checks, [])
  #labels                 = { for k, v in coalesce(var.labels, {}) : k => lower(replace(v, " ", "_")) }
  _backend_services = local.backend_type != "bucket" ? [
    {
      create                  = local.create
      project_id              = local.project_id
      host_project_id         = local.host_project_id
      name                    = lower(trimspace(coalesce(local.name, "backend-service")))
      groups                  = var.groups
      health_checks           = local.health_checks
      session_affinity        = coalesce(var.session_affinity, "NONE")
      logging                 = coalesce(var.logging, false)
      timeout_sec             = coalesce(var.timeout, 30)
      protocol                = upper(trimspace(local.protocol))
      port                    = local.port
      uses_iap                = local.uses_iap
      is_application          = local.is_application
      is_classic              = local.is_classic
      is_regional             = local.region != "global" ? true : false
      region                  = local.is_regional ? local.region : null
      is_internal             = local.is_internal
      negs                    = local.negs
      is_negs                 = length(local.negs) > 0 ? true : false
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
          port_name  = coalesce(ig.port_name, lower("${v.protocol}-${v.port}}"))
        }
      ]
      sample_rate = v.logging ? 1.0 : 0.0
    })
  ]
  ___backend_services = [for i, v in local.__backend_services :
    merge(v, {
      is_psc     = length([for neg in local.new_negs : neg if neg.is_psc]) > 0 ? true : false
      port       = try(coalesce(v.port, v.is_application ? (v.protocol == "HTTP" ? 80 : 443) : null), null)
      port_name  = length(v.instance_groups) > 0 ? one(toset([for ig in v.instance_groups : ig.port_name])) : null
      enable_cdn = v.is_application && !v.is_regional && !v.is_internal ? local.enable_cdn : false
      type       = local.type
      hc_prefix  = "${local.url_prefix}/projects/${v.project_id}/${v.is_regional ? "regions/${v.region}" : "global"}/healthChecks"
      instance_groups = length(local.groups) > 0 ? [] : [for ig in v.instance_groups :
        try(coalesce(
          ig.id,
          ig.zone != null && ig.name != null ? "projects/${ig.project_id}/zones/${ig.zone}/instanceGroups/${ig.name}" : null,
        ), [])
      ]
    })
  ]
  ____backend_services = [for i, v in local.___backend_services :
    merge(v, {
      capacity_scaler = v.is_application ? coalesce(var.capacity_scaler, 1.0) : null
      max_utilization = v.is_application ? coalesce(var.max_utilization, 0.8) : null
      is_gnegs        = length(local.new_gnegs) > 0 ? true : false
      is_rnegs        = length(local.new_rnegs) > 0 ? true : false
      is_znegs        = length(local.new_znegs) > 0 ? true : false
      is_igs          = length(v.instance_groups) > 0 ? true : false
      cdn_cache_mode  = v.enable_cdn ? upper(coalesce(lookup(v.cdn, "cache_mode", null), "CACHE_ALL_STATIC")) : null
    })
  ]
  backend_services = [for i, v in local.____backend_services :
    merge(v, {
      port                            = v.is_application ? null : coalesce(v.port, v.is_gnegs ? 443 : 80)
      port_name                       = v.is_application && v.is_igs ? v.port_name : null
      protocol                        = v.is_gnegs ? "HTTPS" : v.protocol # Assume HTTPS since global NEGs go via Internet
      timeout_sec                     = v.is_rnegs ? null : v.timeout_sec
      load_balancing_scheme           = v.is_application && !local.is_classic ? "${local.type}_MANAGED" : local.type
      locality_lb_policy              = v.is_application && !v.is_classic && !v.is_gnegs ? upper(coalesce(var.locality_lb_policy, "ROUND_ROBIN")) : null
      security_policy                 = v.is_application ? var.security_policy : null
      network                         = v.is_application && v.is_regional && !v.is_internal ? local.network : null
      subnet                          = v.is_application && v.is_regional && !v.is_internal ? local.subnet : null
      balancing_mode                  = !v.is_application ? "CONNECTION" : v.is_gnegs ? null : v.is_negs ? "RATE" : "UTILIZATION"
      max_rate_per_instance           = v.is_application && v.is_igs ? coalesce(var.max_rate_per_instance, 1024) : null
      max_rate_per_endpoint           = v.is_application && v.is_negs && !v.is_gnegs ? 42 : null
      connection_draining_timeout_sec = coalesce(var.connection_draining_timeout, 300)
      max_connections                 = v.protocol == "TCP" && !v.is_regional && !v.is_gnegs ? coalesce(var.max_connections, 8192) : null
      groups = try(coalescelist(v.groups, v.instance_groups,
        [for neg in local.new_gnegs : "${local.url_prefix}/projects/${neg.project_id}/global/networkEndpointGroups/${neg.name}" if neg.backend_name == v.name],
        [for neg in local.new_rnegs : "${local.url_prefix}/projects/${neg.project_id}/regions/${neg.region}/networkEndpointGroups/${neg.name}" if neg.backend_name == v.name],
        [for neg in local.znegs : "${local.url_prefix}/projects/${neg.project_id}/zones/${neg.zone}/networkEndpointGroups/${neg.name}" if neg.backend_name == v.name],
      ), []) # This will result in 'has no backends configured' which is easier to troubleshoot than an ugly error
      health_checks = v.is_gnegs || v.is_psc ? null : flatten([for _ in v.health_checks :
        [startswith(_, local.url_prefix) ? _ : startswith(_, "projects/") ? "${local.url_prefix}/${_}" : "${v.hc_prefix}/${_}"]
      ])
      cdn_cache_mode  = v.enable_cdn ? v.cdn_cache_mode : null
      cdn_default_ttl = v.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 3600 : 0) : null
      cdn_min_ttl     = v.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 60 : 0) : null
      cdn_max_ttl     = v.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 14400 : 0) : null
      cdn_client_ttl  = v.enable_cdn ? (v.cdn_cache_mode == "CACHE_ALL_STATIC" ? 3600 : 0) : null
      index_key       = v.is_regional ? "${v.project_id}/${v.region}/${v.name}" : "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
  _backend_buckets = local.backend_type == "bucket" ? [
    {
      create      = local.create
      project_id  = local.project_id
      name        = lower(trimspace(coalesce(local.name, "backend-bucket-${var.bucket}")))
      bucket_name = var.bucket
      enable_cdn  = local.enable_cdn
    }
  ] : []
  backend_buckets = [for i, v in local._backend_buckets :
    merge(v, {
      description = coalesce(local.description, "Backend Bucket '${v.name}'")
      index_key   = "${v.project_id}/${v.name}"
    }) if v.create == true
  ]
  _iaps = [for i, v in local.backend_services :
    {
      project_id          = v.project_id
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
    })
  ]
  _new_negs = flatten([
    for backend_service in local.__backend_services :
    [
      for i, neg in backend_service.negs :
      {
        project_id      = backend_service.project_id
        host_project_id = backend_service.host_project_id
        name            = lookup(neg, "name", null)
        region          = coalesce(lookup(neg, "region", null), backend_service.region, local.region)
        zone            = lookup(neg, "zone", null)
        network         = coalesce(lookup(neg, "network", null), local.network)
        subnet          = coalesce(lookup(neg, "subnet", null), local.subnet)
        fqdn            = lookup(neg, "fqdn", null)
        ip_address      = lookup(neg, "ip_address", null)
        port            = coalesce(lookup(neg, "port", null), backend_service.port, 443)
        psc_target      = lookup(neg, "psc_target", null)
        instance        = lookup(neg, "instance", null)
        backend_name    = backend_service.name
      }
    ] if backend_service.create == true
  ])
  __new_negs = [
    for i, v in local._new_negs :
    merge(v, {
      name   = "${local.name_prefix != null ? "${local.name_prefix}-" : ""}${coalesce(v.name, "neg-${v.backend_name}-${i}")}"
      region = v.zone != null ? substr(v.zone, 0, length(v.zone) - 2) : coalesce(v.region, "global")
      is_psc = v.psc_target != null ? true : false
    })
  ]
  new_negs = [
    for i, v in local.__new_negs :
    merge(v, {
      network    = startswith(v.network, "projects/") ? v.network : "projects/${v.host_project_id}/global/networks/${v.network}"
      subnetwork = startswith(v.subnet, "projects/") ? v.subnet : "projects/${v.host_project_id}/regions/${v.region}/subnetworks/${v.subnet}"
    })
  ]
  _new_gnegs = [
    for i, v in local.new_negs :
    merge(v, {
      port         = coalesce(v.port, 443) # Going via Internet, so assume we want HTTPS
      default_port = coalesce(v.port, 443)
      network      = null
      subnetwork   = null
    }) if v.region == "global" && v.zone == null && !v.is_psc
  ]
  new_gnegs = [
    for i, v in local._new_gnegs :
    merge(v, {
      network_endpoint_type = v.fqdn != null ? "INTERNET_FQDN_PORT" : "INTERNET_IP_PORT"
      index_key             = "${v.project_id}/${v.name}"
      endpoint_key          = "${v.project_id}/${v.name}/${try(coalesce(v.ip_address), "")}/${try(coalesce(v.fqdn), "")}/${v.port}"
    })
  ]
  _new_rnegs = [
    for i, v in local.new_negs :
    merge(v, {
      port               = coalesce(v.port, 80)
      cloud_run_service  = lookup(v, "cloud_run_service", null)
      psc_target_service = v.psc_target
      region             = v.region
    }) if v.region != null && v.region != "global" && v.zone == null || v.is_psc
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
  __new_rnegs = [
    for i, v in local._new_rnegs :
    merge(v, {
      is_serverless = v.cloud_run_service != null ? true : false
    })
  ]
  existing_znegs = [for neg in local._new_negs :
    {
      project_id   = neg.project_id
      zone         = neg.zone
      name         = neg.name
      backend_name = neg.backend_name
    } if neg.zone != null && neg.instance == null
  ]
  _new_znegs = [
    for i, v in local.new_negs :
    merge(v, {
      network_endpoint_type = "GCE_VM_IP_PORT"
      instance              = lookup(v, "instance", null)
      default_port          = v.port
    }) if v.zone != null
  ]
  __new_znegs = [
    for i, v in local._new_znegs :
    merge(v, {
      index_key = "${v.project_id}/${v.zone}/${v.instance}"
    }) if v.instance != null
  ]
  new_znegs = [
    for i, v in local.__new_znegs :
    merge(v, {
      name       = coalesce(v.name, v.instance)
      ip_address = data.google_compute_instance.zneg_instances[v.index_key].network_interface[0].network_ip
      #ip_address = one([ for instance in data.google_compute_instance.instances : instance.network_interface[0].network_ip if instance.self_link == "lakdjsf" ])
    })
  ]
  znegs = concat(local.existing_znegs, local.new_znegs)
}
