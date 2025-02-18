output "gcs_document_repository" {
  value = module.ingestion_pipeline.pdf_repo_bucket_name
}

output "pubsub_topic_name" {
  value = module.ingestion_pipeline.pubsub_topic_name
}


output "notification_id" {
  value = module.ingestion_pipeline.notification_id
}

output "alloydb_cluster_id" {
  value = module.alloydb_central.cluster_id
}

output "alloydb_primary_instance_id" {
  value = module.alloydb_central.primary_instance_id
}
