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
| `helm/cairn/`                   | **shipped** — initial v0.1.0 |
| `kustomize/`                    | scoped, not implemented |
| `terraform/modules/cairn-aws/`  | scoped, not implemented |
| `terraform/modules/cairn-gcp/`  | scoped, not implemented |
| `terraform/modules/cairn-bare/` | scoped, not implemented |
| `observability/`                | scoped, not implemented |
| `examples/`                     | scoped, not implemented |

Contributions for any of the unimplemented paths are welcome — see
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

Dual MIT / Apache-2.0, matching Cairn upstream.
