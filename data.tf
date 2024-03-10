data "google_compute_instance" "zneg_instances" {
  for_each = { for i, v in local.__new_znegs : v.index_key => v }
  project  = each.value.project_id
  zone     = each.value.zone
  name     = each.value.instance
}

data "google_compute_instance" "instances" {
  for_each = { for i, v in local.__new_znegs : v.index_key => v }
  project  = var.project_id
  zone     = each.value.zone
  name     = each.value.instance
}

