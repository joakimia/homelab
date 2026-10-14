# Platform chart

Creates the homelab namespaces, their Pod Security labels, the baseline NetworkPolicies, and, when enabled, the `homelab-pvc-storage` StorageClass. Install it before every other chart: the other charts expect their namespaces to exist and do not use `--create-namespace`.

## Install

Normally installed first by the cluster profile's `deploy.sh` (see `deploy-set.json`). To install it alone from this directory:

```sh
./scripts/install.sh --values ../../deployment/dev/local-microk8s-cluster-dev/platform/values.yaml --wait
```

The release lives in the `default` namespace. No Secrets are needed.

## Values

| Value | Purpose |
|---|---|
| `namespaces.<key>.name` / `enabled` / `podSecurityEnforce` | Namespace name, whether it is created, and its Pod Security level. |
| `networkPolicies.enabled` | Turns all NetworkPolicies on or off. |
| `networkPolicies.<workload>.podSelector` | Labels that must match the workload charts (`app.kubernetes.io/name`). |
| `networkPolicies.traefik.ports` | Traefik container port names open to outside traffic (default `[web, websecure]`). |
| `networkPolicies.alloy.otlpPorts` | Alloy container port names open to OTLP from every namespace (default `[otlp-grpc, otlp-http]`). |
| `storageClass.*` | Optional StorageClass; the UTM MicroK8s profile uses the `microk8s.io/hostpath` provisioner, the RKE2 profile `rancher.io/local-path`. |

Enabled by default: `hlab-networking` (Traefik, `privileged` because of host ports), `hlab-platform` (cert-manager and the CA Secret; no NetworkPolicies, because the API server must reach the webhook), `hlab-frontend-apps` (pgAdmin, homepage), `hlab-database` (PostgreSQL, PgBouncer), `hlab-observability` (Prometheus, Loki, Tempo, Alloy, Grafana; `baseline`), `hlab-observability-agents` (node-exporter; `privileged`, because it uses the host network, PID namespace, and filesystem), and `hlab-tools` (scheduled jobs such as the homelab periodic cleanup; no NetworkPolicies, because they talk to the API server). The other namespaces are named but disabled. The RKE2 profile also enables `hlab-storage` (local-path-provisioner, `privileged` because its helper pods mount a `hostPath`); it has no NetworkPolicies, so the provisioner can reach the API server.

The policies deny by default and allow DNS plus the paths Traefik → frontend apps, apps → PgBouncer → PostgreSQL, and pgAdmin → PostgreSQL. In `hlab-observability` they cover ingress only: Traefik → Grafana and Prometheus, Grafana and Alloy → Prometheus, Loki, and Tempo, Prometheus → every pod there (scraping), and OTLP from any namespace → Alloy. Egress stays open, because Prometheus, Alloy, and kube-state-metrics talk to the API server and kubelets, which NetworkPolicies cannot select reliably. They only take effect when the CNI enforces NetworkPolicy; MicroK8s Calico and RKE2 Canal do. Mac-side DNS for `*.homelab.com` is not handled here.

## Templates

`namespaces.yaml`, `network-policies.yaml`, `storage-class.yaml`, and `_helpers.tpl` (`platform.validateValues`).
