# local-path-provisioner chart

Runs Rancher's [local-path-provisioner](https://github.com/rancher/local-path-provisioner) in `hlab-storage`. It creates a PersistentVolume for each PVC as a folder on the node where the pod runs (`/opt/local-path-provisioner/<pv>` by default). Use it on clusters without a storage addon, such as RKE2. MicroK8s uses its own hostpath addon instead.

The data stays on that one node and is not replicated. That is fine for a single-node learning cluster; multi-node storage (for example Longhorn) is a later step.

## How it fits together

- The **platform** chart creates the `hlab-storage` namespace (Pod Security `privileged`, because the helper pods mount a `hostPath`) and the `homelab-pvc-storage` StorageClass with `provisioner: rancher.io/local-path`. This chart creates no StorageClass.
- For each new or deleted volume, the provisioner starts a short-lived busybox **helper pod** in `hlab-storage` that runs the `setup` or `teardown` script from the ConfigMap on the node.

## Install

Normally installed by the cluster profile's `deploy.sh` after `platform`. To install it alone:

```sh
./scripts/install.sh --wait
```

No Secrets are needed.

## Values

| Value | Default | Purpose |
|---|---|---|
| `image` | `rancher/local-path-provisioner:v0.0.37` | Provisioner image. |
| `helperImage` | `busybox:1.37.0` | Image for the setup/teardown helper pods. |
| `namespace` | `hlab-storage` | Must match the platform chart's `namespaces.storage.name`. |
| `provisionerName` | `rancher.io/local-path` | Must match the StorageClass `provisioner` in the platform overlay. |
| `nodePath` | `/opt/local-path-provisioner` | Folder on every node for the volumes. |
| `probes.*` | `httpGet /health`, `/ready` | Startup, readiness, and liveness probes. |
| `healthPort` | `8080` | `/health` and `/ready`, inside the pod only. |

## Templates

`serviceaccount.yaml`, `role.yaml`, `rolebinding.yaml`, `clusterrole.yaml`, `clusterrolebinding.yaml`, `configmap.yaml`, `deployment.yaml`, `_helpers.tpl`.
