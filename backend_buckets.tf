# Backend Buckets
locals {
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
}
resource "google_compute_backend_bucket" "default" {
  for_each    = { for i, v in local.backend_buckets : v.index_key => v }
  project     = each.value.project_id
  name        = each.value.name
  bucket_name = each.value.bucket_name
  description = each.value.description
  enable_cdn  = each.value.enable_cdn
}
