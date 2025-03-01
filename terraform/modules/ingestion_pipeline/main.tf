resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployment Service Account"
  project = var.project_name
}

resource "google_project_iam_member" "terraform_roles" {
  for_each = toset([
    "roles/storage.admin",
    "roles/pubsub.admin",
    "roles/compute.admin",
    "roles/dataflow.admin"
  ])
  project = var.project_name
  role    = each.value
  member  = "serviceAccount:${google_service_account.terraform_sa.email}"
}

resource "google_storage_bucket" "pdf_repo" {
  name          = var.pdf_repo_bucket_name
  project = var.project_name
  location      = var.location
  force_destroy = true

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 30 }
  }
}


resource "google_storage_bucket_iam_member" "pdf_repo_role" {
  bucket = google_storage_bucket.pdf_repo.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.terraform_sa.email}"
}

resource "google_compute_network" "default" {
  name                    = "default-network"
  auto_create_subnetworks = true
  project = var.project_name
}

resource "google_dataflow_job" "pubsub_stream" {
  name              = var.dataflow_job_name
  project           = var.project_name
  region            = var.region
  template_gcs_path = "gs://${var.doc_ingestion_bucket}/templates/doc_ingestion_template"
  temp_gcs_location = "gs://${var.doc_ingestion_bucket}/tmp"
  machine_type      = "n1-standard-8"
  network = "default"
  subnetwork = "regions/${var.region}/subnetworks/default-subnet"
  enable_streaming_engine = true
  on_delete = "cancel"

  depends_on = [
    google_storage_bucket_iam_member.pdf_repo_role,
    google_project_iam_member.terraform_roles
  ]
}
