# Homelab shared PVC chart

Base chart for a PersistentVolumeClaim that several workloads mount, for example uploads or exports shared by an app and a job. The claim belongs to this release, not to a workload, and `keep` leaves it (and its data) in place when the release is uninstalled.

The [`homelab`](../homelab/README.md) chart includes it as `homelab-shared-pvc`, off by default. The RKE2 profile turns it on as a `ReadWriteMany` claim on Longhorn in `hlab-filestore`; no workload mounts it yet. Workloads mount it by `name` and must run in its namespace.

Data a single workload owns does not belong here: StatefulSet claims (PostgreSQL, Prometheus, Loki, Tempo, Grafana) already outlive their releases.

## Install

Normally included by the `homelab` chart. As its own release: `./scripts/install.sh <release> --values <claim values> --wait`. The namespace in the values must exist (the default `hlab-filestore` is disabled in the platform chart).

## Values

| Value | Default | Purpose |
|---|---|---|
| `namespace` | `hlab-filestore` | Namespace of the claim; the pods that mount it must run there. |
| `name` | required | Claim name. |
| `storageClassName` | `homelab-pvc-storage` | StorageClass. |
| `accessModes` | `[ReadWriteOnce]` | `ReadWriteMany` needs Longhorn or NFS. With `ReadWriteOnce`, all pods that mount it must run on one node. |
| `size` | `1Gi` | Requested size. |
| `keep` | `true` | `helm.sh/resource-policy: keep`: uninstalling leaves the claim. Delete it with kubectl. |

## Templates

`persistentvolumeclaim.yaml`.
