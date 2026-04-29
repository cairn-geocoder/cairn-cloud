# Cairn on GCP Cloud Run.
#
# Cloud Run only allows ONE container per revision (until 2nd-gen
# sidecars stabilise), so we ship the bundle inside the cairn-serve
# container at build time when targeting Cloud Run, OR fetch it on
# every cold start from GCS via gsutil-equivalent. We pick the latter
# here because it keeps the cairn image vendor-neutral.
#
# Cloud Run starts the container with a single command. We override
# the entrypoint with a small wrapper that:
#   1) downloads gs://<bucket>/<object> via the metadata-server-issued
#      service-account access token
#   2) extracts to /tmp/bundle (Cloud Run's only writable mount)
#   3) execs cairn-serve --bundle /tmp/bundle
#
# The wrapper script is injected via the Cloud Run command/args fields
# rather than a sidecar. Cold start cost: ~bundle download time +
# decompress. For country-scale bundles (~200 MB) this is sub-2-second
# on regional GCS.
#
# CAUTION: this assumes the cairn image has `wget` or `curl`. The
# upstream `ghcr.io/cairn-geocoder/cairn` image ships curl as of
# 0.1.0 specifically to support this flow.

resource "google_service_account" "this" {
  project      = var.project_id
  account_id   = var.name
  display_name = "Cairn (${var.name})"
}

resource "google_storage_bucket_iam_member" "bundle_reader" {
  bucket = var.bundle_gcs_bucket
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.this.email}"
}

locals {
  fetch_url = "https://storage.googleapis.com/${var.bundle_gcs_bucket}/${var.bundle_object}"
  startup_script = trimspace(<<-EOT
    set -eu
    cd /tmp
    TOKEN=$(curl -sH "Metadata-Flavor: Google" \
      "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token" \
      | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')
    curl -fSL --retry 3 -H "Authorization: Bearer $TOKEN" \
      -o bundle.tar.gz "${local.fetch_url}"
    %{if var.bundle_sha256 != ""}
    echo "${var.bundle_sha256}  bundle.tar.gz" | sha256sum -c -
    %{endif}
    mkdir -p /tmp/bundle
    tar -C /tmp/bundle --strip-components=1 -xzf bundle.tar.gz
    rm -f bundle.tar.gz
    exec /usr/local/bin/cairn-serve --bundle /tmp/bundle --bind 0.0.0.0:8080
  EOT
  )
}

resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region
  labels   = var.labels
  ingress  = var.allow_public ? "INGRESS_TRAFFIC_ALL" : "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    service_account = google_service_account.this.email
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    containers {
      image = var.image

      command = ["/bin/sh"]
      args    = ["-c", local.startup_script]

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds    = 5
        failure_threshold = 30
        timeout_seconds   = 3
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        period_seconds    = 30
        timeout_seconds   = 3
        failure_threshold = 3
      }
    }

    timeout = "300s"
  }

  depends_on = [google_storage_bucket_iam_member.bundle_reader]
}

resource "google_cloud_run_v2_service_iam_member" "public" {
  count    = var.allow_public ? 1 : 0
  project  = var.project_id
  location = google_cloud_run_v2_service.this.location
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
