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

# Binding
resource "google_iap_web_backend_service_iam_binding" "default" {
  for_each            = { for i, v in local.iaps : v.index_key => v }
  project             = each.value.project_id
  web_backend_service = each.value.web_backend_service
  role                = each.value.role
  members             = each.value.members
}