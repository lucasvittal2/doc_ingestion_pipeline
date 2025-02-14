# Project Variables
variable "project_id" {
  description = "The ID of GCP project"
  type        = string
}

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
variable "trigger_topic_name"{
  description = "the topic used to send message in order to trigger workflow"
  type = string
}

variable "subscription" {
  description = "The service account used on this project"
  type = string
}

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

variable "dataflow_region" {
  description = "dataflow region"
  type = string
}
