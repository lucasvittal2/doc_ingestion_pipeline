# Project Variables
variable "location" {
  description = "location"
  type        = string
}

variable "region" {
  description = "The region for the resources."
  type        = string
  default     = "us-central1"
}

variable "project_name" {
  description = "GCP project name where resources are deployed."
  type = string
}
# Document Repository Variables

variable "dataflow_job_name" {
  description = "The service account used on this project"
  type = string
}

variable "doc_ingestion_bucket" {
  description = "The env of  this project"
  type = string
}

variable "pdf_repo_bucket_name" {
  description = "The Bucket where pdf will be uploaded"
  type = string
}
