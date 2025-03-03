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
