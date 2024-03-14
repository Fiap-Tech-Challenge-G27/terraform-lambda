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

resource "null_resource" "install_layer_deps" {
    triggers = {
        always_run = "${timestamp()}"
    }

    provisioner "local-exec" {
        working_dir = "${path.module}/layer/nodejs"
        command = " npm install --production "
    }
}

data "archive_file" "authgcfArtefact" {
  output_path = "files_gcf/authgcfArtefact.zip"
  type        = "zip"
  source_file = "${path.module}/gcf/index.js"
}

resource "google_cloudfunctions_function" "auth_gcf" {
  name        = "terraform-gcf"
  runtime     = "nodejs18"
  source_code = data.archive_file.authgcfArtefact.output_path
  entry_point = "index.handler"
  project     = var.project_id
  region      = var.gcp_region
  trigger_http = true
  service_account_email = google_service_account.gcf_execution_role.email
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