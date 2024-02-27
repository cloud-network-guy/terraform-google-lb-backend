locals {
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

# Binding
resource "google_iap_web_backend_service_iam_binding" "default" {
  for_each            = { for i, v in local.iaps : v.index_key => v }
  project             = each.value.project_id
  web_backend_service = each.value.web_backend_service
  role                = each.value.role
  members             = each.value.members
}