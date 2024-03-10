output "backend_services" { value = local.backend_services }
output "negs" { value = [for i, v in local.negs : v] }
output "health_checks" { value = local.health_checks }
