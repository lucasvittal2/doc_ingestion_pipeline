module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  environment                = "dev"
  project_name                   = "bot-especialist-dev"
  region                     = "us-central1"
  service_account_id         = "doc-ingestion-account-dev"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-dev"
  subscription = "ingestion-pipeline-dev-subscription"
  bucket_name= "pdf-repository-dev-680560386191"

}
