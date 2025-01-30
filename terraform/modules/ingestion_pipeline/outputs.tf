output "bucket_name" {
  value = google_storage_bucket.bucket.name
}

output "pubsub_topic_name" {
  value = google_pubsub_topic.topic.name
}

output "notification_id" {
  value = google_storage_notification.bucket_notification.id
}
