# cairn-cloud

Cloud deployment artifacts for [Cairn](https://github.com/cairn-geocoder/cairn) —
the offline, airgap-ready geocoder.

> Cairn itself is a single static Rust binary plus a flat-file bundle.
> This repo is for the operators wiring it into Kubernetes, AWS, GCP,
> or bare-metal Nomad. **Cairn stays vendor-neutral; the cloud assets
> live here so they can move without bumping the geocoder version.**

## What's in here

```
cairn-cloud/
├── helm/cairn/                 Helm chart — published to ghcr.io OCI
├── kustomize/{base,overlays}   Kustomize manifests + dev/prod overlays
├── terraform/modules/
│   ├── cairn-aws/              ECS Fargate + ALB + S3 bundle store
│   ├── cairn-gcp/              Cloud Run + GCS
│   └── cairn-bare/             Nomad + Consul
├── compose/                    docker-compose for local dev
├── observability/
│   ├── grafana/dashboards/     Grafana JSON dashboards
│   └── alerts/                 Prometheus alerting rules
├── examples/                   Working end-to-end demos per platform
└── .github/workflows/          helm lint + kubeconform + OCI release
```

## Quick install (Helm)

```sh
helm install cairn oci://ghcr.io/cairn-geocoder/charts/cairn \
  --version 0.1.0 \
  --namespace cairn --create-namespace \
  --set bundle.source=http \
  --set bundle.http.url=https://bundles.example.com/switzerland.tar.gz \
  --set bundle.http.sha256=<expected>
```

See [`helm/cairn/README.md`](helm/cairn/README.md) for every value,
bundle-source variant (image / http / pvc), and the optional ed25519
signature-verification path.

## Status

| Path | Status |
|---|---|
| `helm/cairn/`                   | **shipped** — chart v0.1.0, OCI on `ghcr.io/cairn-geocoder/charts/cairn` |
| `kustomize/base/`               | **shipped** — flat manifests (Namespace + SA + CM x2 + Svc + Deployment) |
| `kustomize/overlays/dev/`       | **shipped** — single replica, NodePort :30080, no ingress |
| `kustomize/overlays/prod/`      | **shipped** — 3 replicas, HPA, PDB, Ingress, NetworkPolicy egress lockdown |
| `terraform/modules/cairn-aws/`  | **shipped** — ECS Fargate + ALB + CloudWatch + IAM + App Auto Scaling |
| `terraform/modules/cairn-gcp/`  | **shipped** — Cloud Run v2 + GCS-backed bundle + service account |
| `terraform/modules/cairn-bare/` | **shipped** — Nomad service job + Consul registration + bundle prestart |
| `observability/`                | **shipped** — Grafana dashboard + 7 PrometheusRule entries |
| `.github/renovate.json`         | **shipped** — daily auto-bump for Helm, Terraform, GH Actions, Cairn image |
| `examples/`                     | scoped, not implemented |

## Kustomize quickstart

```sh
# Dev — single replica, NodePort :30080, default-deny PSA
kubectl apply -k kustomize/overlays/dev

# Prod — 3 replicas, HPA, PDB, Ingress, NetworkPolicy, topology spread
kubectl apply -k kustomize/overlays/prod
```

Edit the `cairn-bundle-config` ConfigMap in the overlay you're using
to point at your bundle URL + sha256 before applying. The
`bundle-fetch` init container fails closed on sha256 mismatch.

## Terraform quickstart

```hcl
# AWS — ECS Fargate + ALB
module "cairn" {
  source             = "github.com/cairn-geocoder/cairn-cloud//terraform/modules/cairn-aws?ref=main"
  vpc_id             = aws_vpc.this.id
  public_subnet_ids  = aws_subnet.public[*].id
  private_subnet_ids = aws_subnet.private[*].id
  bundle_url         = "https://bundles.example.com/cairn/switzerland-v0.0.2-alpha.tar.gz"
  bundle_sha256      = "<sha256>"
}

# GCP — Cloud Run + GCS
module "cairn" {
  source            = "github.com/cairn-geocoder/cairn-cloud//terraform/modules/cairn-gcp?ref=main"
  project_id        = "my-gcp-project"
  bundle_gcs_bucket = "cairn-bundles"
  bundle_object     = "switzerland-v0.0.2-alpha.tar.gz"
}

# Nomad + Consul — kubernetes-free path
module "cairn" {
  source         = "github.com/cairn-geocoder/cairn-cloud//terraform/modules/cairn-bare?ref=main"
  bundle_url     = "https://bundles.example.com/cairn/switzerland-v0.0.2-alpha.tar.gz"
  bundle_sha256  = "<sha256>"
  instance_count = 2
}
```

Each module's README documents inputs, outputs, and ops gotchas.

## Observability

Drop the Grafana dashboard JSON into your kube-prometheus-stack
config-map and apply the alerting rules with:

```sh
kubectl apply -f observability/alerts/cairn.rules.yaml
```

7 alerts cover liveness, empty admin / point layer, search +
structured error rates above 5% / 10%, reverse-empty-result rate
above 25%, and 4xx flood. Wired only to metrics cairn-serve actually
emits.

Contributions for any of the unimplemented paths are welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

Dual MIT / Apache-2.0, matching Cairn upstream.
