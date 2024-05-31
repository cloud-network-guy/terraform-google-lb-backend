
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

# Data Source to get the IP address of each instance in a Zonal NEG
data "google_compute_instance" "zneg_instances" {
  for_each = { for i, v in local.__new_znegs : v.index_key => v if v.ip_address == null }
  project  = each.value.project_id
  zone     = each.value.zone
  name     = each.value.instance
}

# GCS Backend Bucket
resource "google_compute_backend_bucket" "default" {
  for_each    = { for i, v in local.backend_buckets : v.index_key => v }
  project     = each.value.project_id
  name        = each.value.name
  bucket_name = each.value.bucket_name
  description = each.value.description
  enable_cdn  = each.value.enable_cdn
}
