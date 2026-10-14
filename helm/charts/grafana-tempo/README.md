# Grafana Tempo chart

Installs [Tempo](https://grafana.com/docs/tempo/latest/) in `hlab-observability` as one pod (single binary) with traces on a `homelab-pvc-storage` PVC. It wraps the upstream chart from `grafana-community` (the `grafana/tempo` chart is deprecated), pinned in `Chart.yaml` and `Chart.lock`.

Alloy forwards OTLP traces to `tempo:4317`; Grafana queries `http://tempo:3200`. Apps should send traces to Alloy, not to Tempo directly.

## Install

Installed by the profiles after `platform`. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`.

## Values

Upstream values go under `tempo:` ([reference](https://github.com/grafana-community/helm-charts/tree/main/charts/tempo)). This chart sets:

| Value | Default | Purpose |
|---|---|---|
| `fullnameOverride` | `tempo` | Service and pod names; Grafana and Alloy use them. |
| `tempo.retention` | `72h` | Older trace blocks are deleted. |
| `tempo.resources` | 50m/128Mi, limit 1Gi | Small requests for one node. |
| `tempo.securityContext` | non-root, no capabilities, read-only root | Tempo writes only to `/var/tempo`. |
| `persistence` | 3Gi, `homelab-pvc-storage` | Traces and WAL (a StatefulSet claim: kept on uninstall). Must stay enabled. |

The upstream receivers (OTLP and Jaeger) stay on; only OTLP is used.
