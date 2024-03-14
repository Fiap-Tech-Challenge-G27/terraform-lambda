resource "google_service_account" "gcf_execution_role" {
  account_id = "gcf-execution-role"
}

resource "google_project_iam_binding" "gcf_basic_execution" {
  project = var.project_id
  role    = "roles/cloudfunctions.serviceAgent"
  members = [
    "serviceAccount:${google_service_account.gcf_execution_role.email}",
  ]
}

resource "google_project_iam_binding" "gcf_secret" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.gcf_execution_role.email}",
  ]
}

resource "google_project_iam_binding" "gcf_vpc" {
  project = var.project_id
  role    = "roles/compute.networkUser"
  members = [
    "serviceAccount:${google_service_account.gcf_execution_role.email}",
  ]
}

data "archive_file" "authgcfArtefact" {
  output_path = "files_gcf/authgcfArtefact.zip"
  type        = "zip"
  source_dir = "${path.module}/function"
  # depends_on = [null_resource.install_dependencies]
}

resource "google_storage_bucket" "bucket" {
  name     = "artifact-bucket"
  location = var.gcp_region
}

resource "google_storage_bucket_object" "archive" {
  name   = "function.zip"
  bucket = google_storage_bucket.bucket.name
  source = "files_gcf/authgcfArtefact.zip"
  depends_on = [archive_file.authgcfArtefact]
}

resource "google_cloudfunctions_function" "function" {
  name        = "auth-gcf"
  runtime     = "nodejs20"

  available_memory_mb   = 128
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  entry_point           = "helloGET"
}

# IAM entry for all users to invoke the function
resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.function.project
  region         = google_cloudfunctions_function.function.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}
resource "random_password" "jwtSecret" {
  length           = 16
  special          = true
  override_special = "/@\" "
}

resource "google_secret_manager_secret" "jwt_credentials" {
  project = var.project_id
  secret_id = "jwt_credentials"
}

resource "google_secret_manager_secret_version" "jwt_credentials_version" {
  secret = google_secret_manager_secret.jwt_credentials.name
  payload = jsonencode({
    jwtSecret = random_password.jwtSecret.result
  })
}