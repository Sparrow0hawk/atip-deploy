output "website-bucket" {
  value = google_storage_bucket.static-site.url
}

output "log-bucket" {
  value = google_storage_bucket.logs-bucket.url
}
