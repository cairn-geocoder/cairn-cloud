# Contributing to cairn-cloud

Thanks for considering a contribution.

## Scope

This repo is for **deploying Cairn**. Anything that changes the
geocoder itself (CLI flags, HTTP API, bundle layout) belongs in
[cairn-geocoder/cairn](https://github.com/cairn-geocoder/cairn).

## Development

```sh
# Helm chart
helm lint helm/cairn
helm template cairn helm/cairn > /tmp/render.yaml

# Smoke against a real cluster (kind / k3s / minikube)
helm install cairn ./helm/cairn -n cairn --create-namespace
helm test cairn -n cairn
helm uninstall cairn -n cairn
```

## Pull request checklist

- [ ] `helm lint helm/cairn` passes
- [ ] `helm template` renders without errors against default values
      and at least one non-default values combination
- [ ] Manifests are kubeconform-clean against Kubernetes 1.30
- [ ] New values keys documented in `helm/cairn/values.yaml` with a
      one-paragraph comment explaining intent + safe defaults
- [ ] New templates wrapped in `{{- if ... }}` so they render only
      when the corresponding feature is enabled
- [ ] No secrets / tokens / private keys committed

## Releasing the Helm chart

1. Bump `helm/cairn/Chart.yaml` `version` (chart) and optionally
   `appVersion` (Cairn release).
2. Push and merge.
3. Tag: `git tag chart/cairn/v0.1.1 && git push origin chart/cairn/v0.1.1`.
4. The `release-chart` workflow packages + pushes to
   `oci://ghcr.io/cairn-geocoder/charts/cairn` and creates a GitHub
   Release with the tarball attached.

## License

By contributing you agree your work is licensed dual MIT / Apache-2.0.
