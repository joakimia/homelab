# PostgreSQL chart

Runs one PostgreSQL 17 instance as a StatefulSet with a persistent volume in `hlab-database`. `replicaCount` must be `1` because replication is not configured; the template fails otherwise.

## Install

Normally installed by the cluster profile's `deploy.sh` after `platform` and before `pgbouncer`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/mac-utm-microk8s-cluster/postgres/values.yaml --wait
```

## Secrets

`scripts/install.sh` creates `postgres-credentials` on first install, with `POSTGRES_DB`, `POSTGRES_USER` (both `homelab`) and a random `POSTGRES_PASSWORD`. Later runs reuse it. PgBouncer uses the same Secret. Read the password with:

```sh
kubectl get secret postgres-credentials -n hlab-database -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo
```

## Values

| Value | Default | Purpose |
|---|---|---|
| `database.existingSecret` and `*SecretKey` | `postgres-credentials` | Secret and key names; credentials never go in values. |
| `storage.size` | `2Gi` | PVC size. |
| `storage.storageClassName` | `homelab-pvc-storage` | Created by the platform chart in the UTM profile. |
| `service.port` | `5432` | Service port. |

## Templates

`statefulset.yaml`, `service.yaml`.
