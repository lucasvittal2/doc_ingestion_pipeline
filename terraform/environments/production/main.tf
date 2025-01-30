module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  environment                = "stage"
  region                     = "us-central1"
  service_account_id         = "custom-service-account-stage"
  service_account_display_name = "stage Custom Service Account"
  location = "US"
  project_id = "680560386191"
  trigger_topic_name = "ingestion-pipeline-stage"
  composer_service_account="serviceAccount:ingestion-pipeline-stage-680560386191@cloudcomposer-accounts.iam.gserviceaccount.com"
  project_name = "bot-especialist-stage"
  bucket_name= "pdf-repository-stage-680560386191"
}
