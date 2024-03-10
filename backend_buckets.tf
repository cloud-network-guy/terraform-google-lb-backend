resource "google_compute_backend_bucket" "default" {
  for_each    = { for i, v in local.backend_buckets : v.index_key => v }
  project     = each.value.project_id
  name        = each.value.name
  bucket_name = each.value.bucket_name
  description = each.value.description
  enable_cdn  = each.value.enable_cdn
}
