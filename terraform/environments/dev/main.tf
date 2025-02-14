module "alloydb_central" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"
  cluster_id       = "cluster-us-central1"
  cluster_location = "us-central1"
  project_id       = "the-bot-specialist-dev"
  network_self_link = "projects/the-bot-specialist-dev/global/networks/simple-adb-doc-ingestion" # if you are getting started, change 'the-bot-specialist' to your project name


  automated_backup_policy = {
    location      = "us-central1"
    backup_window = "1800s"
    enabled       = true
    weekly_schedule = {
      days_of_week = ["FRIDAY"],
      start_times  = ["2:00:00:00", ]
    }
    quantity_based_retention_count = 1
    time_based_retention_count     = null
    labels = {
      test = "alloydb-cluster-with-prim"
    }

  }

  continuous_backup_recovery_window_days = 10


  primary_instance = {
    instance_id        = "cluster-us-central1-instance1",
    require_connectors = false
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
  }


  depends_on = [
    google_service_networking_connection.vpc_connection
  ]
}


module "ingestion_pipeline" {
  source                     = "../../modules/ingestion_pipeline"
  project_name                   = "the-bot-specialist-dev"
  region                     = "us-central1"  #If your are starting project, change to your preference region
  dataflow_region = "us-central1"  #If your are starting project, change to your preference region
  location = "US"
  project_id = "150030916493" #If your are starting project, change to your project id
  trigger_topic_name = "ingestion-pipeline-dev"
  subscription = "ingestion-pipeline-dev-subscription"
  pdf_repo_bucket_name= "pdf-repository-dev-150030916493" #If your are starting project, change the project id after last hífen
  doc_ingestion_bucket = "doc-ingestion-pipeline-dev-150030916493" #If your are starting project, change the project id after last hífen
  dataflow_job_name = "doc-ingestion-pipeline-dev-JOB"
}
