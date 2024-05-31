output "negs" { value = [for i, v in local.negs : v] }
output "new_negs" { value = [for i, v in local.new_negs : v] }
#output "health_checks" { value = local.health_checks }
output "backend_services" {
  value = [for i, v in local.backend_services :
    {
      index_key = v.index_key
      id        = v.is_regional ? google_compute_region_backend_service.default[v.index_key].id : google_compute_backend_service.default[v.index_key].id
      name      = v.name
      type      = v.type
      protocol  = v.protocol
      region    = v.region
      groups    = v.groups
      negs = v.negs
    }
  ]
}
output "name" {
  value = local.is_regional ? one([google_compute_region_backend_service.default[one(local.backend_services).index_key].name]) : one([google_compute_backend_service.default[one(local.backend_services).index_key].name])
}
output "id" {
  value = local.is_regional ? one([google_compute_region_backend_service.default[one(local.backend_services).index_key].id]) : one([google_compute_backend_service.default[one(local.backend_services).index_key].id])
}
output "self_link" {
  value = local.is_regional ? one([google_compute_region_backend_service.default[one(local.backend_services).index_key].self_link]) : one([google_compute_backend_service.default[one(local.backend_services).index_key].self_link])
}
