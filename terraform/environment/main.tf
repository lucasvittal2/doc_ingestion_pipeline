module "alloydb_central" {
  source  = "GoogleCloudPlatform/alloy-db/google"
  version = "~> 3.0"
  cluster_id       = "cluster-${var.region}-${var.env}"
  cluster_location = var.region
  project_id       = var.project_name
  network_self_link = "projects/${var.project_name}/global/networks/simple-adb-doc-ingestion-${var.env}"


  automated_backup_policy = {
    location      = var.region
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
    instance_id        = "cluster-${var.region}-instance1-${var.env}",
    require_connectors = false
    ssl_mode           = "ALLOW_UNENCRYPTED_AND_ENCRYPTED"
  }


  depends_on = [
    google_service_networking_connection.vpc_connection
  ]
}


module "ingestion_pipeline" {
  source                     = "../modules/ingestion_pipeline"
  project_name = var.project_name
  location = var.location
  region = var.region
  pdf_repo_bucket_name= "pdf-repository-${var.env}-${var.project_number}"
  doc_ingestion_bucket = "doc-ingestion-pipeline-${var.env}-${var.project_number}"
  dataflow_job_name = "doc-ingestion-pipeline-${var.env}-job"
}
