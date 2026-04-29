# cairn-gcp — Terraform module

Cairn on GCP Cloud Run, fed from a GCS bundle bucket.

## What you get

- Cloud Run v2 service with min/max scaling, CPU/memory caps,
  startup + liveness probes against `/healthz`
- Service account scoped to read-only on the bundle bucket
- Optional public invoker binding (`allow_public = true` for open
  endpoints; false for VPC-internal load balancer / IAM-protected
  deploys)

## How the bundle gets in

Cloud Run only allows one container per revision (gen-1) so we don't
have a separate init container. Instead the cairn image's entrypoint
is overridden with a tiny shell wrapper that downloads the bundle
from `gs://<bucket>/<object>` using the metadata-server token before
exec-ing `cairn-serve`. Cold-start cost is bundle download + tar
extract — sub-2s for country-scale bundles in the same region.

## Usage

```hcl
module "cairn" {
  source = "github.com/cairn-geocoder/cairn-cloud//terraform/modules/cairn-gcp?ref=main"

  project_id        = "my-gcp-project"
  region            = "europe-west6"
  bundle_gcs_bucket = "cairn-bundles"
  bundle_object     = "switzerland-v0.0.2-alpha.tar.gz"
  bundle_sha256     = "<sha256-of-the-tarball>"

  min_instances = 1   # avoid cold start
  max_instances = 10
}

output "cairn_url" {
  value = module.cairn.service_url
}
```

You bring the bucket. The module does NOT create it because GCS
buckets carry retention + lifecycle policies that should stay under
your control.

## Inputs / Outputs

See [`variables.tf`](./variables.tf) + [`outputs.tf`](./outputs.tf).
