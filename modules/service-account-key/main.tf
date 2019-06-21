#------------------------------------------------------------------------------
# Create the app service account and key
#------------------------------------------------------------------------------
resource "google_service_account" "app" {
  account_id   = var.service_account_id
  display_name = var.service_account_name
  project      = var.project_id
}

resource "google_service_account_key" "app" {
  service_account_id = google_service_account.app.name
}

resource "google_project_iam_member" "service-account" {
  count   = length(var.service_account_iam_roles)
  project = var.project_id
  role    = var.service_account_iam_roles[count.index]
  member  = "serviceAccount:${google_service_account.app.email}"
}
