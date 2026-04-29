output "service_url" {
  description = "HTTPS URL of the Cloud Run service. CNAME / Cloud DNS records can alias this."
  value       = google_cloud_run_v2_service.this.uri
}

output "service_name" {
  description = "Cloud Run service name. Useful for `gcloud run services` ops."
  value       = google_cloud_run_v2_service.this.name
}

output "service_account_email" {
  description = "Service account that the Cloud Run revisions run as. Reads the bundle bucket only."
  value       = google_service_account.this.email
}
