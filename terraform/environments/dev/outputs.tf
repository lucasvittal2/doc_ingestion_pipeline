output "gcs_document_repository" {
  value = module.ingestion_pipeline.pdf_repo_bucket_name
}

output "pubsub_topic_name" {
  value = module.ingestion_pipeline.pubsub_topic_name
}


output "notification_id" {
  value = module.ingestion_pipeline.notification_id
}
