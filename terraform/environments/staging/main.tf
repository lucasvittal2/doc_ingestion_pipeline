module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  environment                = "prod"
  region                     = "us-central1"
  service_account_id         = "custom-service-account-prod"
  service_account_display_name = "prod Custom Service Account"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-prod"
  composer_service_account="serviceAccount:ingestion-pipeline-prod-680560386191@cloudcomposer-accounts.iam.gserviceaccount.com"
  project_name = "bot-especialist-prod"
  bucket_name= "pdf-repository-prod-680560386191"
}
