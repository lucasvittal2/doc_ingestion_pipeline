module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  project_name                   = "bot-especialist-dev"
  region                     = "us-central1"
  dataflow_region = "us-east4"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-dev"
  subscription = "ingestion-pipeline-dev-subscription"
  pdf_repo_bucket_name= "pdf-repository-dev-680560386191"
  doc_ingestion_bucket = "doc-ingestion-pipeline-dev"
  dataflow_job_name = "doc-ingestion-pipeline-dev"

}
