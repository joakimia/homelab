# PgBouncer chart

Runs a PgBouncer connection pool in `hlab-database` in front of the `postgres` Service. Clients, such as pgAdmin, connect to `pgbouncer.hlab-database.svc.cluster.local:6432`.

## Install

Normally installed by the cluster profile's `deploy.sh` after `postgres`. To install it alone:

```sh
./scripts/install.sh --values ../../deployment/dev/mac-utm-microk8s-cluster/pgbouncer/values.yaml --wait
```

## Secrets

Uses `postgres-credentials`, which the postgres chart's install script creates. This script stops with a clear message if it is missing.

## Values

| Value | Default | Purpose |
|---|---|---|
| `database.host` / `port` | `postgres` / `5432` | Backend PostgreSQL Service. |
| `database.existingSecret` and `*SecretKey` | `postgres-credentials` | Secret and key names. |
| `pool.mode` / `defaultPoolSize` | `transaction` / `10` | Pool settings. |
| `service.port` | `6432` | Port clients use. |

## Templates

`deployment.yaml`, `service.yaml`.
