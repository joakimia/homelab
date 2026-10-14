# Longhorn chart

**Work in progress.** The chart passes `tests/check.sh` (lint and template), but it has not been deployed to an RKE2 node yet.

Installs [Longhorn](https://longhorn.io/) in `hlab-storage` for the RKE2 profile: block storage that keeps copies of each volume on several nodes. MicroK8s keeps its hostpath addon. It wraps the upstream chart, pinned in `Chart.yaml` and `Chart.lock`; the upstream CRDs are part of its templates.

Longhorn adds a `longhorn` StorageClass, which is opt-in: `homelab-pvc-storage` (local-path-provisioner) stays the class the charts use. A chart moves to Longhorn by asking for `longhorn` (or `homelab-pvc-storage` can point to `driver.longhorn.io` once Longhorn has been verified). The RKE2 profile already uses it for the `homelab-shared` claim in `hlab-filestore` (`ReadWriteMany`, served over NFS by a share-manager pod).

Longhorn itself runs in `hlab-storage` only: its components need the `privileged` level, and the UI finds its backend by the short Service name. Claims on the `longhorn` class can be in any namespace.

## Node requirements

Every node needs `open-iscsi` (with `iscsid` running and the `iscsi_tcp` module loaded) and `nfs-common` (for ReadWriteMany volumes). The RKE2 seeds install both. `hlab-storage` is `privileged`, which Longhorn's manager and instance managers need.

## Install

Installed by the RKE2 profile after `local-path-provisioner`. Alone: `./scripts/install.sh --wait`. The script runs `helm dependency build` first (`charts/` is ignored by Git). To upgrade, change `version` in `Chart.yaml` and run `helm dependency update`; Longhorn only supports upgrades one minor version at a time.

The UI is at `https://longhorn.homelab.com:8443/`. Longhorn has no login: without `ingress.auth.enabled`, everyone who reaches Traefik can create, change, and delete volumes and their data. The RKE2 profile has no Authelia yet, so keep that node's ports off untrusted networks.

Uninstalling needs the `deleting-confirmation-flag` setting set to `true` first; otherwise the uninstall job refuses.

## Values

Upstream values go under `longhorn:` ([reference](https://github.com/longhorn/charts/tree/master/charts/longhorn)). This chart sets:

| Value | Default | Purpose |
|---|---|---|
| `persistence.defaultClass` | `false` | `longhorn` is not the default StorageClass. |
| `persistence.defaultClassReplicaCount` / `defaultSettings.defaultReplicaCount` | `1` | One copy per volume on a single node; raise with more nodes. |
| `csi.*ReplicaCount`, `longhornUI.replicas` | `1` | One replica of each component on a single node. |
| `host` | `longhorn.homelab.com` | Ingress hostname for the UI. |
| `ingress.tls` / `ingress.auth` | HTTPS / off | As in the other UI charts; `auth` needs Authelia. |
| `ingress.backend.service` / `port` | `longhorn-frontend` / `80` | The upstream UI Service. |
| `longhorn.ingress.enabled` | `false` | Must stay off; this chart's own Ingress publishes the UI. |

The upstream chart also installs its own NetworkPolicies for Longhorn's internal components.

## Templates

`ingress.yaml`.
