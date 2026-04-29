variable "name" {
  description = "Resource name prefix."
  type        = string
  default     = "cairn"
}

variable "project_id" {
  description = "GCP project the Cloud Run service + GCS bucket land in."
  type        = string
}

variable "region" {
  description = "GCP region. Pick close to your callers; Cloud Run latency is dominated by network."
  type        = string
  default     = "europe-west6"
}

variable "image" {
  description = "Container image. Cloud Run requires the image to be in a registry the service account can pull from (Artifact Registry, GCR, or — in newer GCP — public ghcr.io is fine for image versions tagged immutable)."
  type        = string
  default     = "ghcr.io/cairn-geocoder/cairn:0.0.2-alpha"
}

variable "bundle_gcs_bucket" {
  description = "Name of an existing GCS bucket containing the bundle objects. The module creates a service account with read access; it does NOT create the bucket — bring your own to keep lifecycle policies + retention under your control."
  type        = string
}

variable "bundle_object" {
  description = "Path within `bundle_gcs_bucket` to the bundle tar.gz."
  type        = string
}

variable "bundle_sha256" {
  description = "Optional SHA-256 of the bundle. Init step fails closed on mismatch."
  type        = string
  default     = ""
}

variable "min_instances" {
  description = "Minimum Cloud Run instances. Set to 1 to avoid cold-start latency."
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum Cloud Run instances."
  type        = number
  default     = 10
}

variable "cpu" {
  description = "CPU per instance. Cloud Run accepts decimal."
  type        = string
  default     = "1"
}

variable "memory" {
  description = "Memory per instance."
  type        = string
  default     = "1Gi"
}

variable "allow_public" {
  description = "Allow unauthenticated invocations. Set false for VPC-only / IAM-protected deploys."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to every Cloud Run service / SA."
  type        = map(string)
  default = {
    app        = "cairn"
    managed-by = "terraform"
  }
}
