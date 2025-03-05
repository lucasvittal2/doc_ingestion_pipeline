output "gcs_document_repository" {
  value = module.ingestion_pipeline.pdf_repo_bucket_name
}

output "alloydb_cluster_id" {
  value = module.alloydb_central.cluster_id
}

output "alloydb_primary_instance_id" {
  value = module.alloydb_central.primary_instance_id
}

output "alloydb_primary_instance"{
  value = module.alloydb_central.primary_instance
}
