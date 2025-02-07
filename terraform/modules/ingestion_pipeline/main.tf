# Use a predefined service account instead of relying on personal account
resource "google_service_account" "terraform_sa" {
  account_id   = "terraform-deployer"
  display_name = "Terraform Deployment Service Account"
  project = var.project_name
}

# Assign necessary IAM roles
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

# Create Pub/Sub Topic
resource "google_pubsub_topic" "topic" {
  name    = var.trigger_topic_name
  project = var.project_name
}

resource "google_pubsub_subscription" "subscription" {
  name  = var.subscription
  project = var.project_name
  topic = google_pubsub_topic.topic.name
  ack_deadline_seconds       = 20
  retain_acked_messages      = true
  message_retention_duration = "86400s"  # 1 day
}

resource "google_storage_bucket" "pdf_repo" {
  name          = var.pdf_repo_bucket_name
  project = var.project_name
  location      = "US"
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

resource "google_storage_bucket" "doc_ingestion" {
  project = var.project_name
  name          = var.doc_ingestion_bucket
  location      = "US"
  force_destroy = true
}

resource "google_compute_network" "default" {
  name                    = "default-network"
  auto_create_subnetworks = true
  project = var.project_name
}

resource "google_dataflow_job" "pubsub_stream" {
  name              = var.dataflow_job_name
  project           = var.project_name
  region            = var.dataflow_region
  template_gcs_path = "gs://${var.doc_ingestion_bucket}/templates/doc_ingestion_template"
  temp_gcs_location = "gs://${var.doc_ingestion_bucket}/tmp"
  machine_type      = "n1-standard-8"
  network = "default"
  subnetwork = "regions/${var.region}/subnetworks/default-subnet"
  enable_streaming_engine = true
  on_delete = "cancel"

  depends_on = [
    google_storage_bucket.doc_ingestion,
    google_storage_bucket_iam_member.pdf_repo_role,
    google_project_iam_member.terraform_roles
  ]
}


## Configure bucket binding notification
data "google_storage_project_service_account" "gcs_account" {
  provider = google-beta
  project  = var.project_name
}

resource "google_pubsub_topic_iam_binding" "binding" {
  provider = google-beta
  topic    = google_pubsub_topic.topic.id
  role     = "roles/pubsub.publisher"
  members  = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_notification" "bucket_notification" {
  bucket         = google_storage_bucket.pdf_repo.name
  topic          = google_pubsub_topic.topic.id
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]

  depends_on = [
    google_pubsub_topic_iam_binding.binding,
    google_storage_bucket_iam_member.pdf_repo_role
  ]
}
