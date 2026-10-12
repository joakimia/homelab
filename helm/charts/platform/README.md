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
| `networkPolicies.traefik.ports` | Traefik container ports open to outside traffic (default `[8080, 8443]`). |
| `storageClass.*` | Optional StorageClass; the UTM profile enables it with the MicroK8s hostpath provisioner. |

Enabled by default: `hlab-networking` (Traefik, `privileged` because of host ports), `hlab-frontend-apps` (pgAdmin, homepage) and `hlab-database` (PostgreSQL, PgBouncer). The other namespaces are named but disabled.

The policies deny by default and allow DNS plus the path Traefik → frontend apps → PgBouncer → PostgreSQL. They only take effect when the CNI enforces NetworkPolicy; MicroK8s Calico does. Mac-side DNS for `*.homelab.com` is not handled here.

## Templates

`namespaces.yaml`, `network-policies.yaml`, `storage-class.yaml`, and `_helpers.tpl` (`platform.validateValues`).
