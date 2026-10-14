# Grafana Alloy chart

Installs [Grafana Alloy](https://grafana.com/docs/alloy/latest/) in `hlab-observability` as one Deployment replica. It wraps the upstream chart, pinned in `Chart.yaml` and `Chart.lock`, and adds the pipeline in `config/config.alloy`:

- **Pod logs** from every namespace, read through the Kubernetes API (`loki.source.kubernetes`) and sent to Loki's push API with the labels `namespace`, `pod`, `container`, and `app`. Over OTLP these labels would become structured metadata instead of stream labels, so `{namespace="..."}` would find nothing. No `hostPath` is needed, so the namespace stays at the `baseline` Pod Security level, and one replica covers every node.
- **Kubernetes events** (`FailedMount`, `OOMKilled`, `BackOff`, `Evicted`, …) to Loki with `job="kubernetes-events"`. With more than one replica they would be sent twice.
- **OTLP** on `alloy.hlab-observability:4317` (gRPC) and `:4318` (HTTP): metrics go to Prometheus, logs to Loki, and traces to Tempo, all over OTLP.

Apps in other namespaces also need NetworkPolicy egress to Alloy before they can send OTLP.

## Install

Installed by the profiles after Loki, Tempo, and Prometheus. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`.

The Alloy UI shows the pipeline and each component's health: `kubectl -n hlab-observability port-forward svc/alloy 12345`, then `http://localhost:12345/`.

## Values

| Value | Default | Purpose |
|---|---|---|
| `configMapName` | `alloy-config` | ConfigMap rendered from `config/config.alloy`; must equal `alloy.alloy.configMap.name`. |
| `endpoints.lokiPush` / `lokiOtlp` | `http://loki:3100/loki/api/v1/push`, `http://loki:3100/otlp` | Loki for pod logs and events, and for OTLP logs from apps. |
| `endpoints.tempo` / `prometheus` | `tempo:4317`, `http://prometheus-server/api/v1/otlp` | Traces and OTLP metrics. |
| `alloy.controller.type` | `deployment` | One replica; pod logs come from the API, not from node files. |
| `alloy.alloy.extraPorts` | `otlp-grpc` 4317, `otlp-http` 4318 | OTLP ports on the pod and Service. |
| `alloy.alloy.securityContext` | uid 473, no capabilities, read-only root | State lives in an `emptyDir` at `/tmp/alloy`. |

Upstream values go under `alloy:` ([reference](https://github.com/grafana/alloy/tree/main/operations/helm/charts/alloy)).

## Templates

`configmap.yaml` (the pipeline, rendered with `tpl`).
