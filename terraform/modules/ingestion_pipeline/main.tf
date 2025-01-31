provider "google" {
  project = var.project_id
  region= var.region
}

# Create Infrastructure  for document upload
data "google_storage_project_service_account" "gcs_account" {
  provider = google-beta
  project = var.project_name
}


resource "google_pubsub_topic" "topic" {
  name     = var.trigger_topic_name
  provider = google-beta
  project = var.project_name
}

resource "google_pubsub_subscription" "subscription" {
  name  = var.subscription
  topic = google_pubsub_topic.topic.name
  ack_deadline_seconds = 20
  retain_acked_messages = true
  message_retention_duration = "86400s"  # 1 day
}

resource "google_pubsub_topic_iam_binding" "binding" {
  provider = google-beta
  topic    = google_pubsub_topic.topic.id
  role     = "roles/pubsub.publisher"
  members  = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}


resource "google_storage_bucket" "bucket" {
  name          = var.pdf_repo_bucket_name
  location      = "US"
  force_destroy = true
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

resource "google_storage_bucket_iam_member" "bucket_role_assignment" {
  bucket = google_storage_bucket.bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

## Configure bucket binding notification

resource "google_storage_notification" "bucket_notification" {
  bucket         = google_storage_bucket.bucket.name
  topic          = google_pubsub_topic.topic.id
  payload_format = "JSON_API_V1"
  event_types    = ["OBJECT_FINALIZE", "OBJECT_METADATA_UPDATE"]

  depends_on = [
    google_pubsub_topic_iam_binding.binding,
    google_storage_bucket_iam_member.bucket_role_assignment
  ]
}
# config dataflow

resource "google_storage_bucket" "bucket1" {
    name          = var.doc_ingestion_bucket
    location      = "US"
    force_destroy = true
}


# provisioning dataflow stream
resource "google_dataflow_job" "pubsub_stream" {
    name = var.dataflow_job_name
    project = var.project_name
    template_gcs_path = "gs://${var.doc_ingestion_bucket}/templates/doc_ingestion_template"
    temp_gcs_location = "gs://${var.doc_ingestion_bucket}/tmp"
    enable_streaming_engine = true
    transform_name_mapping = {
        name = "test_job"
        env = "test"
    }
    on_delete = "cancel"
}
