output "backend_services" {
  value = [for i, v in local.backend_services :
    {
      index_key = v.index_key
      id        = local.is_regional ? google_compute_region_backend_service.default[v.index_key].id : google_compute_backend_service.default[v.index_key].id
      name      = v.name
      protocol  = v.protocol
      region    = v.region
      groups    = v.groups
    }
  ]
}
output "name" {
  value = coalesce(
    local.is_bucket ? one([google_compute_backend_bucket.default[one(local.backend_buckets).index_key].name]) : null,
    local.is_service && local.is_regional ? one([google_compute_region_backend_service.default[one(local.backend_services).index_key].name]) : null,
    local.is_service && !local.is_regional ? one([google_compute_backend_service.default[one(local.backend_services).index_key].name]) : null,
    "error"
  )
}
output "id" {
  value = coalesce(
    local.is_bucket ? one([google_compute_backend_bucket.default[one(local.backend_buckets).index_key].id]) : null,
    local.is_service && local.is_regional ? one([google_compute_region_backend_service.default[one(local.backend_services).index_key].id]) : null,
    local.is_service && !local.is_regional ? one([google_compute_backend_service.default[one(local.backend_services).index_key].id]) : null,
    "error"
  )
}
output "self_link" {
  value = coalesce(
    local.is_bucket ? one([google_compute_backend_bucket.default[one(local.backend_buckets).index_key].self_link]) : null,
    local.is_service && local.is_regional ? one([google_compute_region_backend_service.default[one(local.backend_services).index_key].self_link]) : null,
    local.is_service && !local.is_regional ? one([google_compute_backend_service.default[one(local.backend_services).index_key].self_link]) : null,
    "error"
  )
}
