# Prometheus chart

Installs the [Prometheus](https://prometheus.io/) server and kube-state-metrics in `hlab-observability`. It wraps the standalone upstream chart (no operator, so no CRDs), pinned in `Chart.yaml` and `Chart.lock`.

The server uses the upstream scrape configs: the API server, kubelets and cAdvisor (through the API server proxy), kube-state-metrics, and pods or Services annotated with `prometheus.io/scrape: "true"`. The OTLP receiver is on, so Alloy can push OTLP metrics to `http://prometheus-server/api/v1/otlp`. Grafana queries `http://prometheus-server`. The UI is at `https://prometheus.homelab.com:8443/`.

Prometheus has no login. With `ingress.auth.enabled` (the MicroK8s overlay), Authelia guards the route. Without it, everyone who reaches Traefik can query every metric, push OTLP metrics, and call `/-/reload` and `/-/quit` (the lifecycle API, needed by the config reloader).

## Install

Installed by the profiles after `platform`. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`.

## Values

Upstream values go under `prometheus:` ([reference](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus)). This chart sets:

| Value | Default | Purpose |
|---|---|---|
| `host` | `prometheus.homelab.com` | Ingress hostname. |
| `ingress.tls.enabled` / `clusterIssuer` | `true` / `homelab-ca` | HTTPS with a cert-manager certificate. |
| `ingress.auth.enabled` / `middleware` | `false` / `authelia@file` | Login through Authelia; the route is then HTTPS only. |
| `ingress.backend.service` / `port` | `prometheus-server` / `80` | Service behind the Ingress. |
| `fullnameOverride` | `prometheus` | Server Service `prometheus-server` (port 80). |
| `server.statefulSet.enabled` | `true` | The data claim is kept on uninstall. |
| `server.retention` / `retentionSize` | `3d` / `3GB` | Whichever is reached first. |
| `server.persistentVolume` | 4Gi, `homelab-pvc-storage` | TSDB volume. |
| `server.extraFlags` | `web.enable-lifecycle`, `web.enable-otlp-receiver` | Reload API and OTLP ingest. |
| `server.resources` | 100m/256Mi, limit 1Gi | Small requests for one node. |
| `prometheus-node-exporter.namespaceOverride` | `hlab-observability-agents` | Privileged namespace for the node-exporter DaemonSet. |

node-exporter (node disk, filesystem, memory, network) runs as a DaemonSet in `hlab-observability-agents`: it needs `hostNetwork`, `hostPID`, and `hostPath`, which the `baseline` level of `hlab-observability` forbids, so the schema requires `namespaceOverride` to point elsewhere. Alertmanager and Pushgateway are off.

Prometheus can only scrape pods in other namespaces when their NetworkPolicies allow it; the homelab policies do not yet.

## Templates

`ingress.yaml`.
