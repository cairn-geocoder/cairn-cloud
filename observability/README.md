# Observability

Drop-in Grafana dashboards + Prometheus alerting rules for the
metrics cairn-serve already emits at `/metrics`.

## Files

| Path | Purpose |
|---|---|
| `grafana/dashboards/cairn-overview.json` | 8-panel overview: uptime, admin/point counts, total RPS, RPS by endpoint, error rate by endpoint, reverse-outcome split, bad-request rate. |
| `alerts/cairn.rules.yaml` | 7 PrometheusRule entries: liveness, restart info, empty admin/point layer, search/structured error rate, reverse-empty rate, bad-request flood. |

## Wiring (kube-prometheus-stack)

```yaml
# values.yaml for kube-prometheus-stack — point Grafana sidecar at
# this repo via init container, OR copy the JSON into your own
# dashboards configmap.
grafana:
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
  dashboardsConfigMaps:
    - configMapName: cairn-dashboards
      fileName: cairn-overview.json
```

```yaml
# PrometheusRule CR — wraps observability/alerts/cairn.rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cairn
  labels:
    release: kube-prometheus-stack
spec:
  # paste the `groups:` block from cairn.rules.yaml here
```

## Wiring (vanilla Prometheus)

Mount `cairn.rules.yaml` into your Prometheus pod and reference it in
`prometheus.yml`:

```yaml
rule_files:
  - /etc/prometheus/rules/cairn.rules.yaml
```

## Metrics reference

cairn-serve emits the following at `/metrics` (Prometheus 0.0.4 text):

| Metric | Type | Labels |
|---|---|---|
| `cairn_uptime_seconds`     | gauge   | `bundle_id` |
| `cairn_admin_features`     | gauge   | `bundle_id` |
| `cairn_point_count`        | gauge   | `bundle_id` |
| `cairn_requests_total`     | counter | `endpoint`, `outcome` |

`endpoint` ∈ {`search`, `autocomplete`, `structured`, `reverse`}.
`outcome` ∈ {`ok`, `err`, `bad`} for most endpoints; reverse adds
`pip` / `nearest` / `empty`.
