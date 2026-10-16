# Grafana Loki chart

Installs [Loki](https://grafana.com/docs/loki/latest/) in `hlab-observability` as one pod (monolithic mode) with its chunks and index on a `homelab-pvc-storage` PVC. It wraps the upstream chart from `grafana-community` (the `grafana/loki` chart now packages Grafana Enterprise Logs), pinned in `Chart.yaml` and `Chart.lock`.

Alloy pushes pod logs and OTLP logs to `http://loki:3100`; Grafana queries the same address. There is one tenant (`auth_enabled: false`), so clients send no `X-Scope-OrgID`.

## Install

Installed by the profiles after `platform`. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`.

## Values

Upstream values go under `loki:` ([reference](https://github.com/grafana-community/helm-charts/tree/main/charts/loki)). This chart sets:

| Value | Default | Purpose |
|---|---|---|
| `fullnameOverride` | `loki` | Service and pod names; Grafana and Alloy use them. |
| `deploymentMode` | `Monolithic` | One pod; the read/write/backend targets have 0 replicas. |
| `loki.storage.type` | `filesystem` | Chunks and index on the PVC, no object storage. |
| `loki.limits_config.retention_period` | `72h` | The compactor deletes older logs. |
| `singleBinary.persistence` | 5Gi, `homelab-pvc-storage` | Data volume (a StatefulSet claim: kept on uninstall). |
| `singleBinary.resources` | 100m/256Mi, limit 1Gi | Small requests for one node. |

The gateway, memcached caches, canary, Helm test, and rules sidecar are off.
