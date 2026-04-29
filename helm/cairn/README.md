# cairn (Helm chart)

Deploys [Cairn](https://github.com/cairn-geocoder/cairn) — an offline,
airgap-ready geocoder — into a Kubernetes cluster.

## Highlights

- **Tiny by default** — the chart's resource defaults match Cairn's
  real-world hot RSS (~100 MB on a country-scale bundle).
- **Bundle-source agnostic** — pick `image` (baked-in), `http` (init
  container pulls + sha256-verifies), or `pvc` (operator-mounted).
- **Optional ed25519 signature verification** at startup — `cairn-build
  sign-verify` runs as an init container before `cairn-serve` boots,
  refusing to start the geocoder against a tampered bundle.
- **PodSecurityContext** locked to non-root + read-only rootfs +
  `RuntimeDefault` seccomp + all capabilities dropped.
- **ServiceMonitor** template for kube-prometheus-stack and a custom-
  metric HPA hook for prometheus-adapter (`cairn_http_requests_per_second`).
- **`/healthz` + `/readyz`** probes wired to the dedicated endpoints
  baked into `cairn-serve`.
- **`helm test`** spins up a one-shot probe pod that hits `/healthz` +
  `/v1/search` against the in-cluster service.

## Install

```sh
# OCI registry (recommended)
helm install cairn oci://ghcr.io/cairn-geocoder/charts/cairn \
  --version 0.1.0 \
  --namespace cairn --create-namespace

# Local checkout (for development)
helm install cairn ./helm/cairn -n cairn --create-namespace
```

## Bundle sources

```yaml
# 1) Bundle baked into the image
bundle:
  source: image

# 2) Pulled from a URL on first start
bundle:
  source: http
  http:
    url:    https://bundles.example.com/switzerland-v0.0.2.tar.gz
    sha256: <expected-checksum>
  verify:
    enabled: true
    publicKey: <base64 ed25519 pub>

# 3) Pre-populated PVC (e.g. CSI snapshot)
bundle:
  source: pvc
  pvc:
    claimName: cairn-bundle-switzerland
```

See [`values.yaml`](./values.yaml) for every knob. Defaults are sized
for a single country bundle on commodity hardware; override
`resources.*` for larger deployments.

## Smoke test

```sh
helm test cairn -n cairn
```

Pod runs `curl /healthz` → `curl /v1/search?q=test` against the
in-cluster service. Pass = HTTP 200 from both + valid JSON envelope on
the search response.

## License

Dual MIT / Apache-2.0, matching Cairn itself.
