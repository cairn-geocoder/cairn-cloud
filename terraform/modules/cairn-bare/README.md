# cairn-bare — Terraform module

Cairn on a Nomad + Consul cluster. For operators who want the
Kubernetes-free path.

## What you get

- One Nomad service job with two tasks per allocation:
  - `bundle-fetch` (prestart hook) downloads + sha256-verifies the
    bundle into the alloc shared dir
  - `cairn` runs cairn-serve against the mounted bundle
- Optional Consul service registration with `/healthz` + `/readyz`
  HTTP checks for service-discovery DNS
- Rolling update strategy with canary, auto-revert on health-check
  failure, 10s min-healthy-time

## Usage

```hcl
provider "nomad" {
  address = "http://nomad.service.consul:4646"
}

provider "consul" {
  address = "http://consul.service.consul:8500"
}

module "cairn" {
  source = "github.com/cairn-geocoder/cairn-cloud//terraform/modules/cairn-bare?ref=main"

  name        = "cairn"
  datacenters = ["dc1"]
  count       = 2

  bundle_url    = "https://bundles.example.com/cairn/switzerland-v0.1.0.tar.gz"
  bundle_sha256 = "<sha256>"
}
```

## Inputs / Outputs

See [`variables.tf`](./variables.tf) + [`outputs.tf`](./outputs.tf).
