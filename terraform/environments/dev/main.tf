module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  project_name                   = "the-bot-specialist-dev"
  region                     = "us-central1"
  dataflow_region = "us-central1"
  location = "US"
  project_id = "150030916493"
  trigger_topic_name = "ingestion-pipeline-dev"
  subscription = "ingestion-pipeline-dev-subscription"
  pdf_repo_bucket_name= "pdf-repository-dev-150030916493"
  doc_ingestion_bucket = "doc-ingestion-pipeline-dev"
  dataflow_job_name = "doc-ingestion-pipeline-dev-JOB"
}
